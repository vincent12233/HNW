"use client";
import { useEffect, useState } from "react";
import { Alert, Button, Form, Input, Modal, Space, Table, Typography, message } from "antd";
import { PlusOutlined, ReloadOutlined } from "@ant-design/icons";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

type Staff = { id: string; fullName: string; role: string; status: string; businessProfile?: { employeeNo: string }; _count?: { assignedCustomers: number; createdBusinessUsers: number } };
export default function TeamPage() {
  const [rows,setRows]=useState<Staff[]>([]);
  const [role,setRole]=useState("");
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState("");
  const [open,setOpen]=useState(false);
  const [saving,setSaving]=useState(false);
  const [form]=Form.useForm();
  async function load() {
    setLoading(true); setError("");
    try {
      const [me,team]=await Promise.all([api.get("/auth/me"),api.get("/team")]);
      setRole(me.data.role); setRows(team.data);
    } catch {setError("团队信息加载失败，请刷新重试。");}
    finally {setLoading(false);}
  }
  useEffect(()=>{void load();},[]);
  async function create(values: {employeeNo:string;fullName:string;password:string}) {
    setSaving(true);
    try {await api.post("/team",values);setOpen(false);form.resetFields();message.success("账号创建成功");await load();}
    catch(e:unknown) {const failure=e as {response?:{data?:{message?:string|string[]}}};const detail=failure.response?.data?.message;message.error(Array.isArray(detail)?detail.join("，"):detail||"创建失败");}
    finally {setSaving(false);}
  }
  return <AdminShell>
    <Space orientation="vertical" size="large" style={{width:"100%"}}>
      <Typography.Title level={2}>{role==="ADMIN"?"管理员管理":"我的业务员"}</Typography.Title>
      {error&&<Alert type="error" title={error}/>}
      <Space><Button icon={<ReloadOutlined/>} onClick={load} loading={loading}>刷新</Button>
      <Button type="primary" icon={<PlusOutlined/>} disabled={!role} onClick={()=>setOpen(true)}>{role==="ADMIN"?"创建管理员":"创建业务员"}</Button></Space>
      <Table<Staff> rowKey="id" loading={loading} dataSource={rows} scroll={{x:640}} columns={[
        {title:"员工编号",render:(_,r)=>r.businessProfile?.employeeNo||"-"},
        {title:"姓名",dataIndex:"fullName"},
        {title:"角色",render:(_,r)=>r.role==="MANAGER"?"管理员":"业务员"},
        {title:"状态",render:(_,r)=>r.status==="ACTIVE"?"正常":r.status},
        {title:role==="ADMIN"?"业务员数量":"客户数量",render:(_,r)=>role==="ADMIN"?r._count?.createdBusinessUsers:r._count?.assignedCustomers},
      ]}/>
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
