# keytop JSONL schema v1

系统监测唯一机器接口是：

```bash
keytop value stream --format jsonl --interval 1000 \
  --modules system,cpu,memory,gpu,disk,network,battery
```

每行是一个完整 JSON 对象，包含 `schemaVersion: 1`、`timestampMs`、`sequence`、
`intervalMs`、`system`、`cpu`、`memory`、`gpus`、`disks`、`network`、`battery` 和
`errors`。不可用数值使用 `null`。Shell 直接消费并验证这些字段；没有 CLI 中转层。
