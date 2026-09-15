"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import { Alert, Button, Card, Form, Image, Input, Modal, Popconfirm, Space, Spin, Table, Tag, Typography, message } from "antd";
import { CheckOutlined, CloseOutlined, EyeOutlined, PlusOutlined, ReloadOutlined, SafetyCertificateOutlined } from "@ant-design/icons";
import AdminShell from "@/components/AdminShell";
import ScopedEditButton from "@/components/ScopedEditButton";
import InvitePoolButton from "@/components/InvitePoolButton";
import { api, getApiErrorMessage } from '@/lib/api';
import { loadTeamRecords } from "@/lib/team-records";

type Staff = { id: string; fullName: string; role: string; status: string; businessProfile?: { employeeNo: string; isActive?: boolean }; _count?: { assignedCustomers: number; createdBusinessUsers: number } };
type KycSubmission = {
  id: string; ownerStaffId: string; ownerStaffName: string; documentType: string; status: string; fileName: string; backFileName?: string | null;
  hasSelfie?: boolean; hasSignature?: boolean; recognizedType?: string | null; reviewNote?: string | null;
  createdAt: string; userId: string; fullName: string; phone?: string | null;
  bankDetails?: { accountHolder: string; bankName: string; accountNumber: string; ifscCode: string };
};
type KycFile = { fileName: string; mimeType: string; contentBase64: string };
const kycStatus = (status: string) => status === "APPROVED" ? <Tag color="green">已通过</Tag> : status === "REJECTED" ? <Tag color="red">已拒绝</Tag> : <Tag color="orange">待审核</Tag>;
export default function TeamPage() {
  const [view,setView]=useState("team");
  const [rows,setRows]=useState<Staff[]>([]);
  const [role,setRole]=useState("");
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState("");
  const [open,setOpen]=useState(false);
  const [saving,setSaving]=useState(false);
  const [deleting,setDeleting]=useState("");
  const [form]=Form.useForm();
  const [selectedId,setSelectedId]=useState("");
  const [records,setRecords]=useState<Record<string, unknown>[]>([]);
  const [refreshNonce,setRefreshNonce]=useState(0);
  const [reviewing,setReviewing]=useState<KycSubmission | null>(null);
  const [frontFile,setFrontFile]=useState<KycFile | null>(null);
  const [backFile,setBackFile]=useState<KycFile | null>(null);
  const [evidence,setEvidence]=useState<{selfie: KycFile | null; signature: KycFile | null}>({selfie:null,signature:null});
  const [fileLoading,setFileLoading]=useState(false);
  const [reviewNote,setReviewNote]=useState("");
  const previewGeneration=useRef(0);
  const reviewLock=useRef(false);
  const [reviewSaving,setReviewSaving]=useState(false);
  const frontUrl=useMemo(()=>frontFile ? `data:${frontFile.mimeType};base64,${frontFile.contentBase64}` : "",[frontFile]);
  const backUrl=useMemo(()=>backFile ? `data:${backFile.mimeType};base64,${backFile.contentBase64}` : "",[backFile]);
  async function load() {
    setLoading(true); setError("");
    try {
      const [me,team]=await Promise.all([api.get("/auth/me"),api.get("/team")]);
      setRole(me.data.role); setRows(team.data);
    } catch {setError("团队信息加载失败，请刷新重试。");}
    finally {setLoading(false);}
  }
  useEffect(()=>{
    const syncView = (event?: Event) => {
      const target = event instanceof CustomEvent && typeof event.detail === "string" ? event.detail : window.location.search;
      setView(new URLSearchParams(target.startsWith("?") ? target : target.split("?")[1] || "").get("view") || "team");
    };
    syncView();
    window.addEventListener("popstate", syncView);
    window.addEventListener("admin-navigation", syncView);
    void load();
    return () => { window.removeEventListener("popstate", syncView); window.removeEventListener("admin-navigation", syncView); };
  },[]);
  useEffect(()=>{
    if (view === "team" || !rows.length) { setRecords([]); return; }
    let active = true;
    setRecords([]);
    setLoading(true); setError("");
    const staff = selectedId ? rows.filter(row => row.id === selectedId) : rows;
    const fetchRecords = async () => {
      const combined: Record<string, unknown>[] = [];
      // Bound concurrency when a manager has a large team.
      for (let offset = 0; offset < staff.length; offset += 5) {
        if (!active) return;
        const batch = await Promise.all(staff.slice(offset, offset + 5).map(async member => {
          const items = await loadTeamRecords(async page => {
            const { data } = await api.get(`/team/${member.id}/${view}`, {
              params: view === 'orders' ? {page, pageSize: 100} : undefined,
            });
            return data;
          }, () => active);
          return items.map((item: Record<string, unknown>) => ({...item, ownerStaffId: member.id, ownerStaffName: member.fullName}));
        }));
        combined.push(...batch.flat());
      }
      if (active) setRecords(combined.sort((a, b) => Number(b.status === 'PENDING') - Number(a.status === 'PENDING')));
    };
    fetchRecords().catch(()=>{if(active) setError("客户业务数据加载失败，请重试。未展示不完整的汇总结果。");}).finally(()=>{if(active) setLoading(false);});
    return () => { active = false; };
  },[selectedId,view,refreshNonce,rows]);
  const clearReview = () => {
    previewGeneration.current++;
    setReviewing(null); setFrontFile(null); setBackFile(null); setEvidence({selfie:null,signature:null}); setReviewNote("");
  };
  async function loadKycEvidence(record: KycSubmission) {
    const generation=++previewGeneration.current;
    setFileLoading(true); setError(""); setFrontFile(null); setBackFile(null); setEvidence({selfie:null,signature:null});
    const fetchSide=(side:string)=>api.get<KycFile>(`/team/${record.ownerStaffId}/kyc/${record.id}/file?side=${side}`).then(({data})=>data);
    try {
      const results=await Promise.allSettled([
        fetchSide("front"), record.backFileName ? fetchSide("back") : Promise.resolve(null),
        record.hasSelfie ? fetchSide("selfie") : Promise.resolve(null), record.hasSignature ? fetchSide("signature") : Promise.resolve(null),
      ]);
      const [front,back,selfie,signature]=results;
      if (front.status !== "fulfilled") throw front.status === "rejected" ? front.reason : new Error("证件正面不可用");
      if (generation !== previewGeneration.current) return;
      setFrontFile(front.value); setBackFile(back.status === "fulfilled" ? back.value : null);
      setEvidence({selfie:selfie.status === "fulfilled" ? selfie.value : null,signature:signature.status === "fulfilled" ? signature.value : null});
      const unavailable=[back.status === "rejected" ? "证件反面" : "",selfie.status === "rejected" ? "自拍" : "",signature.status === "rejected" ? "签名" : ""].filter(Boolean);
      if (unavailable.length) setError(`部分资料暂时无法加载：${unavailable.join("、")}。证件正面仍可审核。`);
    } catch (failure: unknown) {
      if (generation !== previewGeneration.current) return;
      const detail = getApiErrorMessage(failure, "");
      setError(detail || "KYC 审核资料加载失败，请重试。");
    } finally { if (generation === previewGeneration.current) setFileLoading(false); }
  }
  async function openKycReview(record: KycSubmission) {
    if (reviewLock.current) return;
    setReviewing(record); setReviewNote(record.reviewNote || ""); await loadKycEvidence(record);
  }
  async function reviewKyc(decision: "APPROVED" | "REJECTED") {
    if (!reviewing || !frontFile || fileLoading || reviewLock.current) return;
    reviewLock.current=true;
    setReviewSaving(true);
    try {
      await api.patch(`/team/${reviewing.ownerStaffId}/kyc`,{submissionId:reviewing.id,decision,note:reviewNote});
      message.success(decision === "APPROVED" ? "KYC 已通过" : "KYC 已拒绝");
      clearReview(); setRefreshNonce(value=>value+1);
    } catch (failure: unknown) {
      const detail = getApiErrorMessage(failure, "");
      message.error(detail || "KYC 审核失败");
    } finally {
      reviewLock.current=false;
      setReviewSaving(false);
    }
  }
  async function create(values: {employeeNo:string;fullName:string;password:string}) {
    setSaving(true);
    try {await api.post("/team",values);setOpen(false);form.resetFields();message.success("账号创建成功");await load();}
    catch(e:unknown) {const failure=e as {response?:{data?:{message?:string|string[]}}};const detail = getApiErrorMessage(failure, "");message.error(detail || "创建失败");}
    finally {setSaving(false);}
  }
  async function removeStaff(row: Staff) {
    setDeleting(row.id);
    try {
      await api.delete(`/team/${row.id}`);
      if (selectedId === row.id) setSelectedId("");
      message.success("账号已删除，登录权限已撤销");
      await load();
    } catch (error: unknown) {
      const detail=(error as {response?:{data?:{message?:string}}}).response?.data?.message;
      message.error(detail || "删除失败，请重试");
    } finally { setDeleting(""); }
  }
  return <AdminShell>
    <Space orientation="vertical" size="large" style={{width:"100%"}}>
      <Typography.Title level={2}>{view === "team" ? (role==="ADMIN"?"管理员管理":"我的业务员") : ({customers:"客户资料",deposits:"客户入金",withdrawals:"客户提现",positions:"客户持仓",orders:"客户订单",trades:"客户成交",kyc:"KYC 审核"} as Record<string,string>)[view]}</Typography.Title>
      {error&&<Alert type="error" title={error}/>}
      {view !== "team" && <Space wrap><Typography.Text>业务员</Typography.Text><select value={selectedId} onChange={e=>setSelectedId(e.target.value)} style={{minWidth:220,padding:8,borderRadius:6,border:"1px solid #d9d9d9"}}><option value="">全部业务员</option>{rows.map(r=><option key={r.id} value={r.id}>{r.fullName}（{r.businessProfile?.employeeNo}）</option>)}</select><Button icon={<ReloadOutlined/>} onClick={()=>setRefreshNonce(value=>value+1)} loading={loading}>刷新</Button><Typography.Text type="secondary">共 {records.length} 条 · 待处理 {records.filter(record=>record.status === 'PENDING').length} 条</Typography.Text></Space>}
      {view === "team" && <Space><Button icon={<ReloadOutlined/>} onClick={load} loading={loading}>刷新</Button>
      <Button type="primary" icon={<PlusOutlined/>} disabled={!role} onClick={()=>setOpen(true)}>{role==="ADMIN"?"创建管理员":"创建业务员"}</Button></Space>}
      {view === "team" ? <Table<Staff> rowKey="id" loading={loading} dataSource={rows} scroll={{x:640}} columns={[
        {title:"员工编号",render:(_,r)=>r.businessProfile?.employeeNo||"-"},
        {title:"姓名",dataIndex:"fullName"},
        ...(role === "MANAGER" ? [{ title: "操作", render: (_: unknown, row: Staff) => <Space wrap>
          <ScopedEditButton name={row.fullName} kind="active" current={row.businessProfile?.isActive ? "ACTIVE" : "SUSPENDED"}
            endpoint={`/team/${row.id}/active`} onSaved={load} />
            <ScopedEditButton name={row.fullName} kind="password" endpoint={`/team/${row.id}/password`} onSaved={load} />
            <InvitePoolButton id={row.id} name={row.fullName} />
        </Space> }] : []),
        {title:"角色",render:(_,r)=>r.role==="MANAGER"?"管理员":"业务员"},
        {title:"状态",render:(_,r)=>r.status==="ACTIVE"?"正常":r.status},
        {title:"删除账号",render:(_,row)=><Popconfirm title={`删除${row.role === "MANAGER" ? "管理员" : "业务员"} ${row.fullName}？`} description="删除后无法登录，保留历史记录；名下有业务员或客户时需先转移归属。" okText="确认删除" cancelText="取消" okButtonProps={{danger:true}} onConfirm={()=>removeStaff(row)} disabled={!!deleting}>
          <Button danger loading={deleting === row.id} disabled={!!deleting && deleting !== row.id}>删除</Button>
        </Popconfirm>},
        {title:role==="ADMIN"?"业务员数量":"客户数量",render:(_,r)=>role==="ADMIN"?r._count?.createdBusinessUsers:r._count?.assignedCustomers},
      ]}/> : view === "kyc" ? <Table<KycSubmission> rowKey="id" loading={loading} dataSource={records as KycSubmission[]} scroll={{x:900}} columns={[
        {title:"所属业务员",dataIndex:"ownerStaffName"},
        {title:"客户",render:(_,record)=> <Space orientation="vertical" size={0}><Typography.Text strong>{record.fullName || "未命名客户"}</Typography.Text><Typography.Text type="secondary">+91 {record.phone || "-"}</Typography.Text></Space>},
        {title:"证件",dataIndex:"documentType",render:value=><Tag>{value}</Tag>},
        {title:"自动识别",dataIndex:"recognizedType",render:value=><Tag color="blue">{value || "-"}</Tag>},
        {title:"状态",dataIndex:"status",render:kycStatus},
        {title:"提交时间",dataIndex:"createdAt",render:value=>value ? new Date(String(value)).toLocaleString("zh-CN") : "-"},
        {title:"操作",render:(_,record)=><Button type="primary" size="small" icon={<SafetyCertificateOutlined/>} disabled={record.status !== "PENDING"} onClick={()=>openKycReview(record)}>审核</Button>},
      ]}/> : <Table<Record<string,unknown>> rowKey={(r,i)=>String(r.id || r.customerId || i)} loading={loading} dataSource={records} scroll={{x:900}} columns={Object.keys(records[0] || {}).filter(k=>!k.toLowerCase().includes("password")).slice(0,8).map(key=>({title:key,dataIndex:key,render:(value:unknown)=>typeof value === "object" ? JSON.stringify(value) : String(value ?? "-")}))}/>}
    </Space>
    <Modal title={role==="ADMIN"?"创建管理员":"创建业务员"} open={open} onCancel={()=>setOpen(false)} onOk={()=>form.submit()} confirmLoading={saving} okText="创建" cancelText="取消">
      <Form form={form} layout="vertical" onFinish={create}>
        <Form.Item name="employeeNo" label="员工编号" rules={[{required:true},{pattern:/^[A-Za-z0-9_-]{3,32}$/,message:"使用 3–32 位字母、数字、下划线或短横线"}]}><Input autoComplete="off"/></Form.Item>
        <Form.Item name="fullName" label="姓名" rules={[{required:true},{min:2,max:100}]}><Input/></Form.Item>
        <Form.Item name="password" label="初始密码" rules={[{required:true},{min:6,max:72,message:"密码长度为 6–72 位"}]}><Input.Password autoComplete="new-password"/></Form.Item>
      </Form>
    </Modal>
    <Modal title="审核团队 KYC" open={!!reviewing} width={860} onCancel={()=>{if(!reviewLock.current) clearReview();}} footer={[
      <Button key="reject" danger icon={<CloseOutlined/>} disabled={fileLoading || !frontFile || reviewSaving} onClick={()=>reviewKyc("REJECTED")}>拒绝</Button>,
      <Button key="approve" type="primary" loading={reviewSaving} icon={<CheckOutlined/>} disabled={fileLoading || !frontFile || reviewSaving} onClick={()=>reviewKyc("APPROVED")}>通过</Button>,
    ]}>
      {reviewing && <Space orientation="vertical" size="middle" style={{width:"100%"}}>
        <Space orientation="vertical" size={2}><Typography.Text strong>{reviewing.fullName || "未命名客户"}</Typography.Text><Typography.Text type="secondary">手机号：+91 {reviewing.phone || "-"}</Typography.Text>{reviewing.bankDetails && <Typography.Text type="secondary">银行：{reviewing.bankDetails.bankName} · {reviewing.bankDetails.accountHolder} · {reviewing.bankDetails.accountNumber}</Typography.Text>}</Space>
        <Card size="small" title="身份证件"><Spin spinning={fileLoading}>{frontFile && <Space orientation="vertical" style={{width:"100%"}}>{frontFile.mimeType.startsWith("image/") ? <Image src={frontUrl} alt={frontFile.fileName} style={{maxHeight:420,objectFit:"contain"}}/> : <iframe title={frontFile.fileName} src={frontUrl} style={{width:"100%",height:480,border:"1px solid #e5e7eb"}}/>}{backFile && backFile.mimeType.startsWith("image/") && <><Typography.Text strong>证件反面</Typography.Text><Image src={backUrl} alt={backFile.fileName} style={{maxHeight:420,objectFit:"contain"}}/></>}</Space>}{!fileLoading && !frontFile && <Button icon={<EyeOutlined/>} onClick={()=>loadKycEvidence(reviewing)}>重新加载证件</Button>}</Spin></Card>
        {!fileLoading && ([['selfie','自拍'],['signature','手写签名']] as const).map(([key,label])=><Card key={key} size="small" title={label}>{evidence[key] ? <Image src={`data:${evidence[key]!.mimeType};base64,${evidence[key]!.contentBase64}`} alt={label} style={{maxHeight:320,objectFit:"contain"}}/> : <Typography.Text type="secondary">该申请未提交此项资料</Typography.Text>}</Card>)}
        <Input.TextArea rows={4} value={reviewNote} onChange={event=>setReviewNote(event.target.value)} placeholder="审核备注" maxLength={1000} showCount/>
      </Space>}
    </Modal>
  </AdminShell>;
}
