import SwiftUI

/// A pulsing placeholder block — native equivalent of the web's `.skeleton`
/// CSS class (`components/Skeleton.tsx`), used while Dashboard/ProjectDetail
/// load for the first time.
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 8

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.line)
            .opacity(reduceMotion ? 0.65 : (pulse ? 0.4 : 0.8))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Dashboard's project-grid loading placeholder — mirrors `ProjectCardSkeleton`.
struct ProjectCardSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonBlock(height: 140, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(height: 10, width: 70, cornerRadius: 3)
                SkeletonBlock(height: 18, width: 130)
                SkeletonBlock(height: 13, width: 170)
                SkeletonBlock(height: 13, width: 110)
                HStack(spacing: 8) {
                    SkeletonBlock(height: 22, width: 60, cornerRadius: 3)
                    SkeletonBlock(height: 22, width: 76, cornerRadius: 3)
                }
                .padding(.top, 4)
            }
            .padding(14)
        }
        .background(Theme.flap).clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// ProjectDetail's full-page loading placeholder — mirrors `ProjectDetailSkeleton`.
struct ProjectDetailSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonBlock(height: 220, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 14) {
                SkeletonBlock(height: 22, width: 90, cornerRadius: 3)
                SkeletonBlock(height: 32, width: 220)
                SkeletonBlock(height: 14, width: 260)
                SkeletonBlock(height: 14, width: 180)
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(height: 11, width: 50)
                            SkeletonBlock(height: 24, width: 40)
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(20)
            .background(Theme.flap)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .padding(.horizontal, 20)
            .offset(y: -60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
