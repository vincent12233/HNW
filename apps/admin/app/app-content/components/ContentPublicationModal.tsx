import { Input, Modal, Select, Space, Typography } from "antd";
import type { ContentEntry } from "../content-editor-support";
const { Text } = Typography;
type PublicationStatus = "DRAFT" | "SCHEDULED" | "PUBLISHED" | "EXPIRED";
type Props = { open: boolean; entries: ContentEntry[]; entryId?: string; status: PublicationStatus; publishAt: string; expiresAt: string; saving: boolean; onCancel: () => void; onOk: () => void; onEntryChange: (id: string) => void; onStatusChange: (status: PublicationStatus) => void; onPublishAtChange: (value: string) => void; onExpiresAtChange: (value: string) => void };
export default function ContentPublicationModal({ open, entries, entryId, status, publishAt, expiresAt, saving, onCancel, onOk, onEntryChange, onStatusChange, onPublishAtChange, onExpiresAtChange }: Props) {
  return (<Modal title="草稿、定时发布与失效" open={open} onCancel={onCancel} onOk={onOk} confirmLoading={saving} okText="保存发布设置"><Space orientation="vertical" style={{ width: "100%" }}><Select showSearch optionFilterProp="label" style={{ width: "100%" }} value={entryId} onChange={onEntryChange} options={entries.map((entry) => ({ value: entry.id, label: `${entry.module} / ${entry.key} / ${entry.locale.toUpperCase()} / v${entry.version}` }))} /><Select style={{ width: "100%" }} value={status} onChange={onStatusChange} options={[{ value: "DRAFT", label: "草稿" }, { value: "SCHEDULED", label: "定时发布" }, { value: "PUBLISHED", label: "立即发布" }, { value: "EXPIRED", label: "已失效" }]} /><Input type="datetime-local" value={publishAt} onChange={(event) => onPublishAtChange(event.target.value)} addonBefore="发布时间" /><Input type="datetime-local" value={expiresAt} onChange={(event) => onExpiresAtChange(event.target.value)} addonBefore="失效时间" /><Text type="secondary">定时发布必须设置发布时间；到达失效时间后客户端会自动停止展示。英文必填法律文档不能保存为草稿或删除。</Text></Space></Modal>);
}



