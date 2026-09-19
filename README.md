# paper-digest-report

WorkBuddy 技能：批量为学术论文生成逐篇「知识要点」Word 报告。

对文献集合中的每一篇论文生成一份独立 `.docx`，固定五个部分：

1. **中英文标题**
2. **主要作者与单位**（单位中文化，保留英文原名括注）
3. **数据与方法简述**
4. **关键图件**：原文图插入 Word，配图注说明 + 解读结论；拿不到原图时显式标注原因
5. **主要结论**（bullet 列表，含关键数字）

## 触发方式

在 WorkBuddy 中说类似的话即可自动触发：

- "帮我把 ima 知识库 XX 里的论文生成知识要点报告"
- "总结 `D:\xxx` 文件夹里的文献，要图件解读，输出 Word"
- "这批 DOI 的论文逐篇做知识要点报告"

## 数据来源（按优先级）

1. **本地 PDF 文件夹**（最优，图件最全、无需联网下载）
2. **ima 知识库**（文字经 ima 接口读解析文本；图件需另找开放获取原文）
3. **DOI / 标题清单**

## 图件获取流水线

1. **PMC 路线**（成功率最高）：`scripts/find_pmcid.sh <doi>` 查 PMCID → `scripts/get_pmc_figs.sh <PMCID> <outdir>` 下载正文高清图
2. **出版社直链 PDF**（nature.com / Copernicus / Frontiers / MDPI / PLOS 等）→ `scripts/extract_figs.py paper.pdf <outdir>` 按图注定位裁切
3. **Unpaywall 兜底**：`scripts/fetch_pdf.sh <doi> <out.pdf>` 遍历全部 OA 位置
4. 全部失败 → 无图出报告并标注原因，不卡死

## 报告生成

每篇论文汇总为一个 spec.json（模板 `assets/spec_template.json`，完整实例 `assets/spec_example.json`），然后：

```bash
python scripts/make_docx.py <spec.json> <out.docx>
```

输出文件名约定：`<一作>_<年份>_<期刊简称>_<中文主题>.docx`

## 依赖

- Python 3.10+，包：`pymupdf`、`python-docx`（建议装在隔离 venv）
- Bash + curl（网络下载）；Windows 下 curl 需加 `--ssl-no-revoke`

## 安装

将本仓库内容放到 `~/.workbuddy/skills/paper-digest-report/` 即可被 WorkBuddy 自动识别。
