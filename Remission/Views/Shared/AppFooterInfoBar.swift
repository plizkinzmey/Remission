import SwiftUI

struct AppFooterInfoBar: View {
    let leftText: String?
    let centerText: String?
    let rightText: String?

    init(
        leftText: String? = nil,
        centerText: String? = nil,
        rightText: String? = nil
    ) {
        self.leftText = leftText
        self.centerText = centerText
        self.rightText = rightText
    }

    var body: some View {
        HStack(spacing: 12) {
            footerCell(text: leftText, alignment: .leading)
            footerCell(text: centerText, alignment: .center)
            footerCell(text: rightText, alignment: .trailing)
        }
        .padding(.horizontal, AppFooterMetrics.contentInset)
        .frame(height: AppFooterMetrics.barHeight)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func footerCell(text: String?, alignment: Alignment) -> some View {
        Text(text ?? " ")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(text == nil ? .clear : .secondary)
            .monospacedDigit()
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}
