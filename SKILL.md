---
name: paper-digest-report
description: 批量为学术论文生成逐篇"知识要点"Word报告。当用户要求对一个文献集合（ima知识库、本地PDF文件夹、或给定DOI清单）逐篇总结知识要点——含中英文标题、作者单位（中文化）、数据与方法、关键图件截取与图注解读、主要结论——并输出每篇一份Word文档时使用。触发词：论文知识要点、文献要点报告、逐篇总结论文、论文图件截取解读、批量文献报告、帮我总结这批论文。
agent_created: true
---

# paper-digest-report：论文知识要点 Word 报告批量生成

## 目标产出

对文献集合中的**每一篇论文**生成一份独立 `.docx` 报告，统一放入用户指定的输出文件夹（默认在桌面新建，如 `桌面\<主题>论文知识要点\`）。每份报告固定 5 个部分：

1. **中英文标题**（英文原标题 + 中文译题）
2. **主要作者与单位**（单位尽量翻译成中文，保留英文原名括注）
3. **数据与方法简述**（数据来源、时段、方法框架，3–6 句）
4. **关键图件**：原文图插入 Word，每张图配"图注说明 + 解读结论"；拿不到原图时显式标注"无原文图"及原因
5. **主要结论**（bullet 列表，含关键数字）

## 执行环境（Windows 已验证）

- Python 用托管隔离环境：`C:/Users/AcTor/.workbuddy/binaries/python/envs/default/Scripts/python.exe`（依赖 `pymupdf python-docx requests`，缺则 pip 安装到该 venv，禁止全局安装）。脚本内可用 `WB_PY` 环境变量覆盖解释器路径。
- **运行 Python 走 PowerShell 工具**（本机 Bash 沙箱对 python.exe 有拦截）；**网络下载走 Bash 里的 curl**（python requests 在沙箱内可能被断连）。
- curl 参数约定：`--ssl-no-revoke -L -A "Mozilla/5.0 ..."`；下载 PDF 后**必须验证文件头为 `%PDF` 且大小 > 30KB**，验证失败即换源，不要把 HTML 错误页当 PDF。

## 数据来源决策（按优先级）

1. **本地 PDF 文件夹**（最优）：用户若提供本地原文目录，直接从本地读，跳过一切网络下载。
2. **ima 知识库**（文字内容）：加载 ima-mcp 技能，用 `get_knowledge_list` 列条目（注意去重：同一论文可能有多个副本，按标题判重），用 `fetch_media_content` 读解析后的全文文本。**注意：ima 接口只暴露解析文本，拿不到原始 PDF 和图片**，因此图件必须另找原文（见下节）。
3. **给定 DOI/标题清单**：文字内容用 Crossref/Europe PMC 摘要 + 可获取的全文。

## 图件获取流水线（核心难点，按顺序尝试）

对每篇论文（假设工作目录 `work/<slug>/`，图件存 `work/<slug>/figs/`）：

1. **PMC 路线（成功率最高）**：
   - `bash scripts/find_pmcid.sh <doi>` 查 PMCID（经 Europe PMC REST）
   - 有 PMCID → `bash scripts/get_pmc_figs.sh <PMCID> <outdir>` 直接下载正文高清图（cdn.ncbi.nlm.nih.gov 图床，自动过滤补充材料）
2. **出版社直链 PDF**：nature 系试 `https://www.nature.com/articles/<文章号>.pdf`；Copernicus 系（nhess 等）、Frontiers、MDPI、PLOS 直链通常可直接下。拿到 PDF 后：
   - `python scripts/extract_figs.py <paper.pdf> <outdir> [max_figs]`（按图注定位裁切正文图，输出 fig_N.png + figs.json）
3. **Unpaywall 兜底**：`bash scripts/fetch_pdf.sh <doi> <out.pdf>` 遍历全部 OA 位置（自动优先机构库/预印本，降权出版社反爬域名），成功后同上用 extract_figs.py 裁图。
4. **全部失败 → 无图出报告**：在 spec 里写 `figures_note` 说明原因（如"Nature/Lancet/AGU 反爬限制，无法获取原文图"），**不要卡死**。

已知坑：
- Nature/Science/Lancet/AGU/Elsevier/AMS 官网多有反爬（403 或返回 HTML）；Science Advances、Nature Communications 等 OA 刊基本都在 PMC 有全文，**优先走 PMC 路线**。
- 接受稿（accepted manuscript）PDF 可能**不含插图**，裁图前先用 Read 工具抽查 1–2 张输出图确认有内容。
- 下载的图必须抽查（Read 看图），防止把占位图/错误页插进报告。

## 报告生成

每篇论文汇总为一个 spec.json（模板：`assets/spec_template.json`，完整实例：`assets/spec_example.json`），然后：

```powershell
& $py scripts/make_docx.py <spec.json> <out.docx>
```

spec 字段：`title_en, title_cn, journal, year, doi, authors[], affiliations[], data_methods, figures[{path,caption,note}], figures_note, conclusions[]`。输出文件名约定：`<一作>_<年份>_<期刊简称>_<中文主题>.docx`。

## 批量策略（>10 篇时）

- 按 4–6 篇一批派并行子代理（Agent 工具，run_in_background），批次不要更大（实测 7 篇/批易断连）。
- 每个子代理只负责：读正文 → 下载图件 → 写 spec → 生成 docx 到 `out/`；主代理统一复制到最终输出文件夹并核对篇数。
- 断连批次由主代理手动补齐；最终抽查 2–3 份 docx（unzip -l 看 word/media 数量）确认图片已嵌入。

## 内容质量要求

- 作者单位中文化时保留英文原名，如"南京大学大气科学学院（School of Atmospheric Sciences, Nanjing University）"。
- 每张图的 `note` 写"该图支撑的具体结论"，不是复述图注。
- 结论 bullet 必须含论文中的关键数值（幅度、百分比、时段）。
- 内容以论文正文为准；ima 解析文本与 DOI 元数据冲突时以正文为准。

## 完成后

- 用 present_files 展示全部 docx（按重要性排序）。
- 告知用户：总篇数、有图/无图各几篇、无图原因；若用户后续提供本地 PDF，可为无图篇目补图重做。
