# V3.0 Generated Images

本目录保存 V3.0 专项图片产物和校验报告。

## PNG Images

- `v3-flowcharts-specialized.png`：流程图专项图片，10 个完整面板。
- `v3-sequence-diagrams-specialized.png`：时序图专项图片，7 个完整面板。
- `v3-page-prototypes-specialized.png`：页面原型专项图片，14 个完整面板。
- `v3-html-static-prototype-overview.png`：HTML 静态原型图片，9 个完整面板。

## SVG Sources

同名 `.svg` 文件是可缩放源文件，便于后续转 PDF、嵌入文档或继续编辑。

## Verification

- `v3-specialized-image-verification.md`
- `v3-specialized-image-verification.json`

校验项包括：

- 预期面板数和实际面板数一致。
- 图片布局未溢出画布。
- PNG 尺寸与设计画布一致。
- 图片非空像素比例达到阈值。
- 文件大小达到有效图片阈值。

重新生成命令：

```bash
node tool/render_v3_specialized_images.cjs
```
