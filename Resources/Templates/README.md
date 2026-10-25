# 空白模板来源

这些文件只用于创建新的空白文档，不包含用户原有文档中的内容。

- `Blank.docx`、`Blank.xlsx`、`Blank.pptx`：使用 `scripts/generate_templates.py` 中的 python-docx、openpyxl、python-pptx 生成；三种格式均经过 ZIP/XML 完整性及对应库重新读取检查。
- `Blank.pages`：2026-10-25 在本机 Pages Creator Studio 中选择“基本 → 空白”，实际保存为 Pages 原生文件；正文、页眉和页脚均为空。
- `Blank.numbers`：同日在 Numbers Creator Studio 中选择“基本 → 空白”，实际保存为 Numbers 原生文件；一张空白表格，没有录入数据或公式。
- `Blank.key`：同日在 Keynote Creator Studio 中选择白色主题，移除首张幻灯片的所有占位对象，实际保存为 Keynote 原生文件；一张纯白空幻灯片。

三种 iWork 文件均确认是包含 `.iwa` 数据的有效原生 ZIP 文档，并在原应用中实际保存成功。重新生成这些文件需使用相应 Apple 应用，不能通过重命名 Office 文件替代。
