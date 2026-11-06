import SwiftUI

struct AboutSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localizer) private var localizer
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(theme.dividerColor)
                .frame(width: 42, height: 6)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    Text(localizer.text(.profileMoreAboutTitle))
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text(localizer.text(.profileMoreAboutBody))
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Button {
                dismiss()
            } label: {
                Text(localizer.text(.actionDone))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#6F86C9"))
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
        }
        .background(
            theme.elevatedBackground
                .ignoresSafeArea()
        )
    }
}

#Preview {
    AboutSheetView()
        .environment(\.appTheme, .dark)
        .environment(\.localizer, AppLocalizer(language: .simplifiedChinese))
}
