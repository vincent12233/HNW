"use client";
import { useEffect, useState } from "react";
import { Alert, Button, Form, Input, Modal, Space, Table, Typography, message } from "antd";
import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

type Staff = { id: string; fullName: string; role: string; status: string; businessProfile?: { employeeNo: string }; _count?: { assignedCustomers: number; createdBusinessUsers: number } };
export default function TeamPage() {
  const [view,setView]=useState("team");
  const [rows,setRows]=useState<Staff[]>([]);
  const [role,setRole]=useState("");
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState("");
  const [open,setOpen]=useState(false);
  const [saving,setSaving]=useState(false);
  const [form]=Form.useForm();
  const [selectedId,setSelectedId]=useState("");
  const [records,setRecords]=useState<Record<string, unknown>[]>([]);
  async function load() {
    setLoading(true); setError("");
    try {
      const [me,team]=await Promise.all([api.get("/auth/me"),api.get("/team")]);
      setRole(me.data.role); setRows(team.data);
    } catch {setError("团队信息加载失败，请刷新重试。");}
    finally {setLoading(false);}
  }
  useEffect(()=>{ const params = new URLSearchParams(window.location.search); setView(params.get("view") || "team"); void load(); },[]);
  useEffect(()=>{ if (view !== "team" && rows.length && !selectedId) setSelectedId(rows[0].id); },[rows,selectedId,view]);
  useEffect(()=>{
    if (view === "team" || !selectedId) { setRecords([]); return; }
    setLoading(true); setError("");
    const endpoint = view === "orders" ? `/team/${selectedId}/orders` : `/team/${selectedId}/${view}`;
    api.get(endpoint).then(({data})=>setRecords(Array.isArray(data) ? data : data?.items || [])).catch(()=>setError("客户业务数据加载失败，请重试。")).finally(()=>setLoading(false));
  },[selectedId,view]);
  async function create(values: {employeeNo:string;fullName:string;password:string}) {
    setSaving(true);
    try {await api.post("/team",values);setOpen(false);form.resetFields();message.success("账号创建成功");await load();}
    catch(e:unknown) {const failure=e as {response?:{data?:{message?:string|string[]}}};const detail=failure.response?.data?.message;message.error(Array.isArray(detail)?detail.join("，"):detail||"创建失败");}
    finally {setSaving(false);}
  }
  return <AdminShell>
    <Space orientation="vertical" size="large" style={{width:"100%"}}>
      <Typography.Title level={2}>{view === "team" ? (role==="ADMIN"?"管理员管理":"我的业务员") : ({customers:"客户资料",deposits:"客户入金",withdrawals:"客户提现",positions:"客户持仓",orders:"客户订单",trades:"客户成交",kyc:"KYC 审核"} as Record<string,string>)[view]}</Typography.Title>
      {error&&<Alert type="error" title={error}/>}
      {view !== "team" && <Space wrap><Typography.Text>业务员</Typography.Text><select value={selectedId} onChange={e=>setSelectedId(e.target.value)} style={{minWidth:220,padding:8,borderRadius:6,border:"1px solid #d9d9d9"}}><option value="">请选择业务员</option>{rows.map(r=><option key={r.id} value={r.id}>{r.fullName}（{r.businessProfile?.employeeNo}）</option>)}</select><Button icon={<ReloadOutlined/>} onClick={()=>setSelectedId(selectedId)} loading={loading}>刷新</Button></Space>}
      {view === "team" && <Space><Button icon={<ReloadOutlined/>} onClick={load} loading={loading}>刷新</Button>
      <Button type="primary" icon={<PlusOutlined/>} disabled={!role} onClick={()=>setOpen(true)}>{role==="ADMIN"?"创建管理员":"创建业务员"}</Button></Space>}
      {view === "team" ? <Table<Staff> rowKey="id" loading={loading} dataSource={rows} scroll={{x:640}} columns={[
        {title:"员工编号",render:(_,r)=>r.businessProfile?.employeeNo||"-"},
        {title:"姓名",dataIndex:"fullName"},
        {title:"角色",render:(_,r)=>r.role==="MANAGER"?"管理员":"业务员"},
        {title:"状态",render:(_,r)=>r.status==="ACTIVE"?"正常":r.status},
        {title:role==="ADMIN"?"业务员数量":"客户数量",render:(_,r)=>role==="ADMIN"?r._count?.createdBusinessUsers:r._count?.assignedCustomers},
      ]}/> : <Table<Record<string,unknown>> rowKey={(r,i)=>String(r.id || r.customerId || i)} loading={loading} dataSource={records} scroll={{x:900}} columns={Object.keys(records[0] || {}).filter(k=>!k.toLowerCase().includes("password")).slice(0,8).map(key=>({title:key,dataIndex:key,render:(value:unknown)=>typeof value === "object" ? JSON.stringify(value) : String(value ?? "-")}))}/>}
    </Space>
    <Modal title={role==="ADMIN"?"创建管理员":"创建业务员"} open={open} onCancel={()=>setOpen(false)} onOk={()=>form.submit()} confirmLoading={saving} okText="创建" cancelText="取消">
      <Form form={form} layout="vertical" onFinish={create}>
        <Form.Item name="employeeNo" label="员工编号" rules={[{required:true},{pattern:/^[A-Za-z0-9_-]{3,32}$/,message:"使用 3–32 位字母、数字、下划线或短横线"}]}><Input autoComplete="off"/></Form.Item>
        <Form.Item name="fullName" label="姓名" rules={[{required:true},{min:2,max:100}]}><Input/></Form.Item>
        <Form.Item name="password" label="初始密码" rules={[{required:true},{min:12,max:72,message:"密码长度为 12–72 位"}]}><Input.Password autoComplete="new-password"/></Form.Item>
      </Form>
    </Modal>
  </AdminShell>;
}
