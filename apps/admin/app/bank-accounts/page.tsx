"use client";

import { ReloadOutlined, SearchOutlined } from "@ant-design/icons";
import { Alert, Button, Card, Input, Space, Table, Tag, Typography } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/components/AdminShell";
import { api } from "@/lib/api";

const { Title, Paragraph, Text } = Typography;
type BankAccount = { id:string; bankName:string; accountHolder:string; accountNumber:string; ifscCode:string; isPrimary:boolean; createdAt:string; user:{fullName:string;phone?:string;customerNo?:string} };

export default function BankAccountsPage() {
  const [rows,setRows]=useState<BankAccount[]>([]), [loading,setLoading]=useState(false), [error,setError]=useState(""), [query,setQuery]=useState("");
  async function load(){setLoading(true);setError("");try{const response=await api.get<BankAccount[]>("/admin/bank-accounts");setRows(Array.isArray(response.data)?response.data:[]);}catch(e:any){setError(e.response?.data?.message||"银行账户加载失败");}finally{setLoading(false);}}
  useEffect(()=>{load();},[]);
  const data=useMemo(()=>{const q=query.trim().toLowerCase();return q?rows.filter(row=>[row.bankName,row.accountHolder,row.accountNumber,row.ifscCode,row.user.fullName,row.user.phone,row.user.customerNo].some(v=>String(v??"").toLowerCase().includes(q))):rows;},[query,rows]);
  const columns:ColumnsType<BankAccount>=[
    {title:"客户",render:(_,r)=><Space orientation="vertical" size={0}><Text strong>{r.user.fullName}</Text><Text type="secondary">{r.user.customerNo||"-"} / +91 {r.user.phone||"-"}</Text></Space>},
    {title:"开户名",dataIndex:"accountHolder"},{title:"银行",dataIndex:"bankName"},{title:"账户",dataIndex:"accountNumber",render:v=><Text copyable>{v}</Text>},{title:"IFSC",dataIndex:"ifscCode"},{title:"状态",render:(_,r)=><Tag color="green">{r.isPrimary?"主要账户":"已添加"}</Tag>},{title:"添加时间",dataIndex:"createdAt",render:v=>new Date(v).toLocaleString("zh-CN")},
  ];
  return <AdminShell><Space orientation="vertical" size="large" style={{width:"100%"}}><div><Title level={2}>银行账户</Title><Paragraph type="secondary">客户在 APP 添加后立即同步显示，无需审核。</Paragraph></div>{error&&<Alert type="error" showIcon message={error}/>}<Card><Space style={{marginBottom:16}}><Input prefix={<SearchOutlined/>} allowClear placeholder="搜索客户、银行、账号或 IFSC" value={query} onChange={e=>setQuery(e.target.value)} style={{width:380}}/><Button icon={<ReloadOutlined/>} onClick={load}>刷新</Button></Space><Table rowKey="id" columns={columns} dataSource={data} loading={loading} scroll={{x:1100}}/></Card></Space></AdminShell>;
}
