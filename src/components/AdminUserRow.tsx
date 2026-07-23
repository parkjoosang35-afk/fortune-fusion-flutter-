"use client";

import { useActionState, useState } from "react";
import {
  updateAdminUser,
  changeAdminUserRole,
  toggleAdminUserStatus,
  deleteAdminUser,
  type AdminUserFormState,
} from "@/app/actions/admin-users";

interface Role {
  id: number;
  code: string;
  name: string;
}

interface AdminUserRowProps {
  adminUser: {
    id: number;
    email: string;
    name: string;
    roleId: number;
    roleCode: string;
    roleName: string;
    is2faEnabled: boolean;
    status: string;
    lastLoginAt: Date | null;
  };
  roles: Role[];
  isSelf: boolean;
  canWrite: boolean;
  canDelete: boolean;
}

const initialState: AdminUserFormState = {};

function formatDate(d: Date | null): string {
  if (!d) return "-";
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default function AdminUserRow({ adminUser, roles, isSelf, canWrite, canDelete }: AdminUserRowProps) {
  const [editState, editAction, editPending] = useActionState(updateAdminUser, initialState);
  const [roleState, roleAction, rolePending] = useActionState(changeAdminUserRole, initialState);
  const [statusState, statusAction, statusPending] = useActionState(toggleAdminUserStatus, initialState);
  const [deleteState, deleteAction, deletePending] = useActionState(deleteAdminUser, initialState);

  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(adminUser.name);
  const [is2fa, setIs2fa] = useState(adminUser.is2faEnabled);

  const [roleModalOpen, setRoleModalOpen] = useState(false);
  const [newRoleId, setNewRoleId] = useState(String(adminUser.roleId));

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40 align-top">
      <td className="px-4 py-3 text-slate-300">
        {adminUser.email}
        {isSelf && <span className="ml-1 text-xs text-indigo-400">(본인)</span>}
      </td>
      <td className="px-4 py-3">
        {editing ? (
          <form
            action={async (fd) => {
              await editAction(fd);
              setEditing(false);
            }}
            className="flex flex-col gap-1"
          >
            <input type="hidden" name="id" value={adminUser.id} />
            <input
              type="text"
              name="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="rounded border border-slate-700 bg-slate-800 px-2 py-1 text-xs text-white"
            />
            <label className="flex items-center gap-1 text-xs text-slate-400">
              <input
                type="checkbox"
                name="is2faEnabled"
                checked={is2fa}
                onChange={(e) => setIs2fa(e.target.checked)}
                className="accent-indigo-500"
              />
              2FA
            </label>
            <div className="flex gap-1">
              <button
                type="submit"
                disabled={editPending}
                className="rounded bg-indigo-600 px-2 py-1 text-xs text-white hover:bg-indigo-500"
              >
                저장
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="rounded bg-slate-700 px-2 py-1 text-xs text-slate-300 hover:bg-slate-600"
              >
                취소
              </button>
            </div>
            {editState.error && <p className="text-xs text-red-400">{editState.error}</p>}
          </form>
        ) : (
          <div>
            <div className="text-slate-200">{adminUser.name}</div>
            <div className="text-xs text-slate-500">2FA: {adminUser.is2faEnabled ? "사용" : "미사용"}</div>
          </div>
        )}
      </td>
      <td className="px-4 py-3 text-slate-300">{adminUser.roleName}</td>
      <td className="px-4 py-3">
        {adminUser.status === "active" ? (
          <span className="rounded-full bg-emerald-950/60 px-2 py-0.5 text-xs text-emerald-400">활성</span>
        ) : (
          <span className="rounded-full bg-red-950/60 px-2 py-0.5 text-xs text-red-400">정지</span>
        )}
      </td>
      <td className="px-4 py-3 text-xs text-slate-500">{formatDate(adminUser.lastLoginAt)}</td>
      <td className="px-4 py-3">
        {canWrite && (
          <div className="flex flex-wrap gap-1">
            {!editing && (
              <button
                onClick={() => setEditing(true)}
                className="rounded bg-slate-700 px-2 py-1 text-xs text-slate-300 hover:bg-slate-600"
              >
                수정
              </button>
            )}
            {!isSelf && (
              <button
                onClick={() => setRoleModalOpen(true)}
                className="rounded bg-amber-900/60 px-2 py-1 text-xs text-amber-300 hover:bg-amber-900"
              >
                역할변경
              </button>
            )}
            {!isSelf && (
              <form action={statusAction}>
                <input type="hidden" name="id" value={adminUser.id} />
                <input
                  type="hidden"
                  name="newStatus"
                  value={adminUser.status === "active" ? "suspended" : "active"}
                />
                <button
                  type="submit"
                  disabled={statusPending}
                  className="rounded bg-slate-700 px-2 py-1 text-xs text-slate-300 hover:bg-slate-600"
                >
                  {adminUser.status === "active" ? "정지" : "활성화"}
                </button>
              </form>
            )}
            {canDelete && !isSelf && (
              <form action={deleteAction}>
                <input type="hidden" name="id" value={adminUser.id} />
                <button
                  type="submit"
                  disabled={deletePending}
                  className="rounded bg-red-900/60 px-2 py-1 text-xs text-red-300 hover:bg-red-900"
                >
                  삭제
                </button>
              </form>
            )}
          </div>
        )}
        {statusState.error && <p className="mt-1 text-xs text-red-400">{statusState.error}</p>}
        {deleteState.error && <p className="mt-1 text-xs text-red-400">{deleteState.error}</p>}

        {roleModalOpen && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
            <form
              action={async (fd) => {
                await roleAction(fd);
                setRoleModalOpen(false);
              }}
              className="w-full max-w-sm rounded-xl border border-slate-700 bg-slate-900 p-5"
            >
              <h4 className="mb-3 text-sm font-semibold text-white">
                역할 변경 — {adminUser.name} ({adminUser.email})
              </h4>
              <p className="mb-3 text-xs text-amber-400">
                ⚠ 05§4.5 워크플로우: 역할 변경은 2단계 확인이 필수입니다. 사유 입력 및 본인
                비밀번호 재확인이 필요합니다.
              </p>
              <input type="hidden" name="id" value={adminUser.id} />
              <div className="mb-2 flex flex-col gap-1 text-xs text-slate-400">
                새 역할
                <select
                  name="newRoleId"
                  value={newRoleId}
                  onChange={(e) => setNewRoleId(e.target.value)}
                  className="rounded border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white"
                >
                  {roles.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.name} ({r.code})
                    </option>
                  ))}
                </select>
              </div>
              <div className="mb-2 flex flex-col gap-1 text-xs text-slate-400">
                변경 사유(필수)
                <input
                  type="text"
                  name="reason"
                  required
                  className="rounded border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white"
                />
              </div>
              <div className="mb-3 flex flex-col gap-1 text-xs text-slate-400">
                본인 비밀번호(2단계 확인)
                <input
                  type="password"
                  name="confirmPassword"
                  required
                  className="rounded border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-white"
                />
              </div>
              {roleState.error && (
                <p className="mb-2 rounded bg-red-950/60 px-2 py-1 text-xs text-red-400">
                  {roleState.error}
                </p>
              )}
              <div className="flex gap-2">
                <button
                  type="submit"
                  disabled={rolePending}
                  className="rounded bg-indigo-600 px-3 py-1.5 text-xs text-white hover:bg-indigo-500"
                >
                  {rolePending ? "처리 중..." : "역할 변경 확인"}
                </button>
                <button
                  type="button"
                  onClick={() => setRoleModalOpen(false)}
                  className="rounded bg-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-600"
                >
                  취소
                </button>
              </div>
            </form>
          </div>
        )}
      </td>
    </tr>
  );
}
