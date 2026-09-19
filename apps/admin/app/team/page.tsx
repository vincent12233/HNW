"use client";
import { useEffect, useRef, useState } from "react";
import { Alert, Button, Form, Input, Modal, Popconfirm, Space, Table, Typography, message } from "antd";
import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import AdminShell from "@/components/AdminShell";
import KycReviewList from "@/components/KycReviewList";
import KycReviewModal from "@/components/KycReviewModal";
import ScopedEditButton from "@/components/ScopedEditButton";
import InvitePoolButton from "@/components/InvitePoolButton";
import { api, getApiErrorMessage } from '@/lib/api';
import {
  KYC_REVIEW_COPY,
  acquireReviewLock,
  buildKycReviewBody,
  canSubmitKycReview,
  collectPreviewGaps,
  partialPreviewMessage,
  releaseReviewLock,
  type KycDecision,
  type KycFilePreview,
  type KycSubmissionView,
} from "@/lib/kyc-review";
import { loadTeamRecords } from "@/lib/team-records";

type Staff = { id: string; fullName: string; role: string; status: string; businessProfile?: { employeeNo: string; isActive?: boolean }; _count?: { assignedCustomers: number; createdBusinessUsers: number } };
const EMPTY_KYC_FILES = {
  front: null,
  back: null,
  selfie: null,
  signature: null,
} as { front: KycFilePreview | null; back: KycFilePreview | null; selfie: KycFilePreview | null; signature: KycFilePreview | null };
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
  const [reviewing,setReviewing]=useState<KycSubmissionView | null>(null);
  const [kycFiles,setKycFiles]=useState(EMPTY_KYC_FILES);
  const [fileLoading,setFileLoading]=useState(false);
  const [reviewNote,setReviewNote]=useState("");
  const [kycPreviewError,setKycPreviewError]=useState("");
  const previewGeneration=useRef(0);
  const reviewLock=useRef(false);
  const [reviewSaving,setReviewSaving]=useState(false);
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
    if (reviewLock.current) return;
    previewGeneration.current++;
    setReviewing(null); setKycFiles(EMPTY_KYC_FILES); setReviewNote(""); setKycPreviewError("");
  };
  async function loadKycEvidence(record: KycSubmissionView) {
    const generation=++previewGeneration.current;
    setFileLoading(true); setKycPreviewError(""); setKycFiles(EMPTY_KYC_FILES);
    const fetchSide=(side:string)=>api.get<KycFilePreview>(`/team/${record.ownerStaffId}/kyc/${record.id}/file?side=${side}`).then(({data})=>data);
    try {
      const results=await Promise.allSettled([
        fetchSide("front"), record.backFileName ? fetchSide("back") : Promise.resolve(null),
        record.hasSelfie ? fetchSide("selfie") : Promise.resolve(null), record.hasSignature ? fetchSide("signature") : Promise.resolve(null),
      ]);
      const [front,back,selfie,signature]=results;
      if (front.status !== "fulfilled") throw front.status === "rejected" ? front.reason : new Error("证件正面不可用");
      if (generation !== previewGeneration.current) return;
      setKycFiles({
        front: front.value,
        back: back.status === "fulfilled" ? back.value : null,
        selfie: selfie.status === "fulfilled" ? selfie.value : null,
        signature: signature.status === "fulfilled" ? signature.value : null,
      });
      const unavailable = collectPreviewGaps({
        backRequested: Boolean(record.backFileName),
        backFailed: back.status === "rejected",
        selfieRequested: Boolean(record.hasSelfie),
        selfieFailed: selfie.status === "rejected",
        signatureRequested: Boolean(record.hasSignature),
        signatureFailed: signature.status === "rejected",
      });
      if (unavailable.length) setKycPreviewError(partialPreviewMessage(unavailable));
    } catch (failure: unknown) {
      if (generation !== previewGeneration.current) return;
      const detail = getApiErrorMessage(failure, "");
      setKycPreviewError(detail || KYC_REVIEW_COPY.previewError);
    } finally { if (generation === previewGeneration.current) setFileLoading(false); }
  }
  async function openKycReview(record: KycSubmissionView) {
    if (reviewLock.current) return;
    setReviewing(record); setReviewNote(record.reviewNote || ""); await loadKycEvidence(record);
  }
  async function reviewKyc(decision: KycDecision) {
    if (
      !reviewing ||
      !reviewing.ownerStaffId ||
      !canSubmitKycReview({
        status: reviewing.status,
        hasFrontFile: Boolean(kycFiles.front),
        fileLoading,
        saving: reviewSaving,
        decision,
        note: reviewNote,
      })
    ) return;
    if (!acquireReviewLock(reviewLock)) return;
    setReviewSaving(true);
    try {
      await api.patch(`/team/${reviewing.ownerStaffId}/kyc`, buildKycReviewBody(reviewing.id, decision, reviewNote));
      message.success(decision === "APPROVED" ? KYC_REVIEW_COPY.approveSuccess : KYC_REVIEW_COPY.rejectSuccess);
      previewGeneration.current++;
      setReviewing(null); setKycFiles(EMPTY_KYC_FILES); setReviewNote(""); setKycPreviewError("");
      setRefreshNonce(value=>value+1);
    } catch (failure: unknown) {
      const detail = getApiErrorMessage(failure, "");
      message.error(detail || KYC_REVIEW_COPY.reviewFailure);
    } finally {
      releaseReviewLock(reviewLock);
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
      {error && view !== "kyc" && <Alert type="error" title={error}/>}
      {view === "kyc" && <Typography.Paragraph type="secondary">{KYC_REVIEW_COPY.description} 管理员通过所属业务员接口审核，不使用业务员待审接口。</Typography.Paragraph>}
      {view !== "team" && <Space wrap><Typography.Text>业务员</Typography.Text><select value={selectedId} onChange={e=>setSelectedId(e.target.value)} aria-label="按业务员筛选" style={{minWidth:220,padding:8,borderRadius:6,border:"1px solid #d9d9d9"}}><option value="">全部业务员</option>{rows.map(r=><option key={r.id} value={r.id}>{r.fullName}（{r.businessProfile?.employeeNo}）</option>)}</select><Button icon={<ReloadOutlined aria-hidden/>} aria-label="刷新客户业务数据" onClick={()=>setRefreshNonce(value=>value+1)} loading={loading}>刷新</Button><Typography.Text type="secondary">共 {records.length} 条 · 待处理 {records.filter(record=>record.status === 'PENDING').length} 条</Typography.Text></Space>}
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
      ]}/> : view === "kyc" ? <KycReviewList
        items={records as KycSubmissionView[]}
        loading={loading}
        error={error}
        includeOwner
        busy={reviewSaving}
        onRetry={()=>setRefreshNonce(value=>value+1)}
        onOpen={openKycReview}
      /> : <Table<Record<string,unknown>> rowKey={(r,i)=>String(r.id || r.customerId || i)} loading={loading} dataSource={records} scroll={{x:900}} columns={Object.keys(records[0] || {}).filter(k=>!k.toLowerCase().includes("password")).slice(0,8).map(key=>({title:key,dataIndex:key,render:(value:unknown)=>typeof value === "object" ? JSON.stringify(value) : String(value ?? "-")}))}/>}
    </Space>
    <Modal title={role==="ADMIN"?"创建管理员":"创建业务员"} open={open} onCancel={()=>setOpen(false)} onOk={()=>form.submit()} confirmLoading={saving} okText="创建" cancelText="取消">
      <Form form={form} layout="vertical" onFinish={create}>
        <Form.Item name="employeeNo" label="员工编号" rules={[{required:true},{pattern:/^[A-Za-z0-9_-]{3,32}$/,message:"使用 3–32 位字母、数字、下划线或短横线"}]}><Input autoComplete="off"/></Form.Item>
        <Form.Item name="fullName" label="姓名" rules={[{required:true},{min:2,max:100}]}><Input/></Form.Item>
        <Form.Item name="password" label="初始密码" rules={[{required:true},{min:12,max:72,message:"密码长度为 12–72 位"}]}><Input.Password autoComplete="new-password"/></Form.Item>
      </Form>
    </Modal>
    <KycReviewModal
      open={!!reviewing}
      submission={reviewing}
      files={kycFiles}
      fileLoading={fileLoading}
      previewError={kycPreviewError}
      note={reviewNote}
      onNoteChange={setReviewNote}
      saving={reviewSaving}
      onClose={clearReview}
      onRetryPreview={() => { if (reviewing) void loadKycEvidence(reviewing); }}
      onSubmit={reviewKyc}
    />
  </AdminShell>;
}
