"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { api } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [employeeNo, setEmployeeNo] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function login() {
    setError("");
    setSubmitting(true);

    try {
      const response = await api("/auth/login", {
        method: "POST",
        body: JSON.stringify({
          employeeNo: employeeNo.trim().toUpperCase(),
          password,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        setError(Array.isArray(data.message) ? data.message.join("，") : data.message || "登录失败");
        return;
      }

      localStorage.setItem("accessToken", data.accessToken);
      localStorage.setItem("supportUser", JSON.stringify(data.user || {}));
      router.push("/dashboard");
    } catch {
      setError("无法连接服务器");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="min-h-screen bg-slate-100 flex items-center justify-center px-4">
      <section className="w-full max-w-md rounded-lg bg-white p-8 shadow-sm border border-slate-200">
        <div className="mb-8">
          <div className="h-10 w-10 rounded bg-blue-600 text-white flex items-center justify-center font-bold">
            H
          </div>
          <h1 className="mt-4 text-2xl font-bold text-slate-900">HNW 客服后台</h1>
          <p className="mt-2 text-sm text-slate-500">使用员工编号和密码登录</p>
        </div>

        <label className="block text-sm font-medium text-slate-700">员工编号</label>
        <input
          className="mt-2 mb-4 w-full rounded border border-slate-300 px-3 py-2 outline-none focus:border-blue-600"
          placeholder="例如 SUPPORT001"
          value={employeeNo}
          onChange={(event) => setEmployeeNo(event.target.value)}
        />

        <label className="block text-sm font-medium text-slate-700">密码</label>
        <input
          className="mt-2 mb-4 w-full rounded border border-slate-300 px-3 py-2 outline-none focus:border-blue-600"
          placeholder="请输入密码"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") login();
          }}
        />

        {error && <p className="mb-4 rounded bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p>}

        <button
          className="w-full rounded bg-blue-600 px-4 py-2 font-medium text-white disabled:opacity-60"
          onClick={login}
          disabled={submitting}
        >
          {submitting ? "登录中..." : "登录"}
        </button>
      </section>
    </main>
  );
}
