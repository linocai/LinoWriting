import SwiftUI

struct WritingSettingsView: View {
    @State private var targetWords = "3000 ± 400 字"
    @State private var scenePolicy = "最多 2 个自然场景，不拆成 Scene Plan"
    @State private var newCharacterPolicy = "默认禁止，除非结构化 Prompt 批准"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TopBarView(kicker: "写作设置", title: "默认规则服务于少打扰、多兜底") {
                    Button("保存设置") {
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(alignment: .top, spacing: 16) {
                    CardView {
                        CardHeader(
                            title: "生成策略",
                            subtitle: "这些设置影响每章生成，但不会增加额外确认步骤。"
                        )
                        CardBody {
                            TextField("目标字数", text: $targetWords)
                                .textFieldStyle(.roundedBorder)
                            TextField("每章最多场景", text: $scenePolicy)
                                .textFieldStyle(.roundedBorder)
                            Picker("新命名角色策略", selection: $newCharacterPolicy) {
                                Text("默认禁止，除非结构化 Prompt 批准").tag("默认禁止，除非结构化 Prompt 批准")
                                Text("允许但需要基础文件确认").tag("允许但需要基础文件确认")
                            }
                        }
                    }

                    CardView {
                        CardHeader(
                            title: "审核策略",
                            subtitle: "审计自动运行，不要求你逐个确认。"
                        )
                        CardBody {
                            MetricRowView(title: "S0 硬错误", value: "自动要求修复", tone: .red)
                            MetricRowView(title: "S1 明显问题", value: "提示给用户", tone: .orange)
                            MetricRowView(title: "S2 可选优化", value: "折叠展示", tone: .blue)
                            ContentBlock("主流程边界") {
                                Text("章节流程只保留输入、审核、修改、批准和确认基础文档更新。")
                                    .font(.callout)
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .background(AppTheme.background)
    }
}
