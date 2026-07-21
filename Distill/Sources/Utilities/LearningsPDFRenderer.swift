import SwiftUI
import UIKit

@MainActor
struct LearningsPDFRenderer {

    // MARK: - Colours
    private static let navy       = UIColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1)
    private static let cyan       = UIColor(red: 0.25, green: 0.65, blue: 0.90, alpha: 1)
    private static let blue       = UIColor(red: 0.15, green: 0.40, blue: 0.80, alpha: 1)
    private static let insightBg  = UIColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 1)
    private static let pageBg     = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
    private static let charcoal   = UIColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1)
    private static let mutedGrey  = UIColor(red: 0.55, green: 0.58, blue: 0.63, alpha: 1)
    private static let cardBorder = UIColor(red: 0.82, green: 0.86, blue: 0.92, alpha: 1)

    static func render(book: Book, accentColor: Color, learnings: [Learning]) -> URL? {
        let pageSize = CGSize(width: 612, height: 792)
        let margin: CGFloat = 48
        let contentWidth = pageSize.width - margin * 2
        let totalPages = estimatePageCount(learnings: learnings, contentWidth: contentWidth, margin: margin, pageSize: pageSize)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(book.title) — Distill Summary.pdf")

        do {
            try renderer.writePDF(to: tempURL) { ctx in
                var yOffset: CGFloat = 0
                var currentPage = 0

                func ps(lineSpacing: CGFloat = 3, align: NSTextAlignment = .left) -> NSParagraphStyle {
                    let p = NSMutableParagraphStyle()
                    p.lineSpacing = lineSpacing
                    p.alignment = align
                    return p
                }

                func textHeight(_ str: NSAttributedString, width: CGFloat) -> CGFloat {
                    str.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                     options: .usesLineFragmentOrigin, context: nil).height
                }

                // MARK: Page chrome
                func beginPage() {
                    ctx.beginPage()
                    currentPage += 1

                    // Off-white background
                    pageBg.setFill()
                    UIRectFill(CGRect(origin: .zero, size: pageSize))

                    yOffset = margin

                    // Page header (skip on cover page 1)
                    if currentPage > 1 {
                        let headerAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                            .foregroundColor: mutedGrey
                        ]
                        let leftStr = NSAttributedString(string: "\(book.title) Executive Summary", attributes: headerAttrs)
                        let rightStr = NSAttributedString(string: "Page \(currentPage) of \(totalPages)", attributes: headerAttrs)
                        leftStr.draw(at: CGPoint(x: margin, y: 20))
                        let rightW = rightStr.size().width
                        rightStr.draw(at: CGPoint(x: pageSize.width - margin - rightW, y: 20))

                        // thin rule
                        mutedGrey.withAlphaComponent(0.3).setFill()
                        UIRectFill(CGRect(x: margin, y: 34, width: contentWidth, height: 0.5))
                        yOffset = 52
                    }
                }

                func pageFooter() {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: mutedGrey
                    ]
                    let str = NSAttributedString(string: "\(book.title) Executive Summary", attributes: attrs)
                    str.draw(at: CGPoint(x: margin, y: pageSize.height - 28))
                    let right = NSAttributedString(string: "Page \(currentPage) of \(totalPages)", attributes: attrs)
                    right.draw(at: CGPoint(x: pageSize.width - margin - right.size().width, y: pageSize.height - 28))
                }

                func checkPageBreak(neededHeight: CGFloat) {
                    if yOffset + neededHeight > pageSize.height - 48 {
                        pageFooter()
                        beginPage()
                    }
                }

                // MARK: Cover block
                func drawCover() {
                    let coverHeight: CGFloat = 110
                    let coverRect = CGRect(x: margin - 12, y: yOffset, width: contentWidth + 24, height: coverHeight)
                    let coverPath = UIBezierPath(roundedRect: coverRect, cornerRadius: 10)
                    navy.setFill()
                    coverPath.fill()

                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 26, weight: .heavy),
                        .foregroundColor: UIColor.white,
                        .kern: 1.5
                    ]
                    let subtitleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                        .foregroundColor: cyan
                    ]
                    let taglineAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.55)
                    ]

                    let titleStr = NSAttributedString(string: book.title.uppercased(), attributes: titleAttrs)
                    let subtitleStr = NSAttributedString(string: book.author, attributes: subtitleAttrs)
                    let taglineStr = NSAttributedString(string: "Executive Summary & Chapter Overview", attributes: taglineAttrs)

                    var innerY = yOffset + 22
                    titleStr.draw(at: CGPoint(x: margin, y: innerY))
                    innerY += 28
                    subtitleStr.draw(at: CGPoint(x: margin, y: innerY))
                    innerY += 18
                    taglineStr.draw(at: CGPoint(x: margin, y: innerY))

                    yOffset += coverHeight + 28
                }

                // MARK: Section header (left blue border + uppercase label)
                func drawSectionHeader(_ label: String) {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                        .foregroundColor: charcoal,
                        .kern: 0.8
                    ]
                    let str = NSAttributedString(string: label.uppercased(), attributes: attrs)
                    let h = textHeight(str, width: contentWidth - 16) + 16

                    checkPageBreak(neededHeight: h + 16)

                    // Left blue accent bar
                    blue.setFill()
                    UIRectFill(CGRect(x: margin - 12, y: yOffset, width: 4, height: h))

                    str.draw(in: CGRect(x: margin, y: yOffset + 8, width: contentWidth - 16, height: h))
                    yOffset += h + 12
                }

                // MARK: Chapter card
                func drawLearning(_ learning: Learning) {
                    let cardPad: CGFloat = 14
                    let innerW = contentWidth - cardPad * 2
                    let insightIndent: CGFloat = 12

                    let chapterAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: blue
                    ]
                    let bodyAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
                        .foregroundColor: charcoal,
                        .paragraphStyle: ps(lineSpacing: 3)
                    ]

                    // Split text: first sentence = body context, rest = key insight
                    let sentences = learning.text.components(separatedBy: ". ").filter { !$0.isEmpty }
                    let bodyText: String
                    let insightText: String
                    if sentences.count > 1 {
                        bodyText = sentences.dropLast().joined(separator: ". ") + "."
                        insightText = sentences.last ?? ""
                    } else {
                        bodyText = learning.text
                        insightText = ""
                    }

                    let chapterStr = NSAttributedString(string: learning.chapter.isEmpty ? "" : learning.chapter, attributes: chapterAttrs)
                    let bodyStr = NSAttributedString(string: bodyText, attributes: bodyAttrs)

                    let chH = learning.chapter.isEmpty ? 0 : textHeight(chapterStr, width: innerW) + 6
                    let bodyH = textHeight(bodyStr, width: innerW)

                    // Key insight callout
                    let insightW = innerW - insightIndent - 4
                    let insightLabelAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                        .foregroundColor: charcoal
                    ]
                    let insightBodyAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                        .foregroundColor: charcoal,
                        .paragraphStyle: ps(lineSpacing: 2)
                    ]

                    var insightBlockH: CGFloat = 0
                    var insightFullStr: NSAttributedString?
                    if !insightText.isEmpty {
                        let combined = NSMutableAttributedString()
                        combined.append(NSAttributedString(string: "Key Insight: ", attributes: insightLabelAttrs))
                        combined.append(NSAttributedString(string: insightText, attributes: insightBodyAttrs))
                        insightFullStr = combined
                        insightBlockH = textHeight(combined, width: insightW) + 20
                    }

                    let totalCardH = cardPad + chH + bodyH + (insightText.isEmpty ? 0 : 12 + insightBlockH) + cardPad

                    checkPageBreak(neededHeight: totalCardH + 10)

                    // Card background + border
                    let cardRect = CGRect(x: margin - 12, y: yOffset, width: contentWidth + 24, height: totalCardH)
                    let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
                    UIColor.white.setFill()
                    cardPath.fill()
                    cardBorder.setStroke()
                    cardPath.lineWidth = 0.8
                    cardPath.stroke()

                    var innerY = yOffset + cardPad

                    if !learning.chapter.isEmpty {
                        chapterStr.draw(in: CGRect(x: margin, y: innerY, width: innerW, height: chH + 4))
                        innerY += chH
                    }

                    bodyStr.draw(in: CGRect(x: margin, y: innerY, width: innerW, height: bodyH + 4))
                    innerY += bodyH + 12

                    if let insightStr = insightFullStr {
                        // Insight callout box
                        let insightBoxRect = CGRect(x: margin, y: innerY, width: innerW, height: insightBlockH)
                        let insightPath = UIBezierPath(roundedRect: insightBoxRect, cornerRadius: 5)
                        insightBg.setFill()
                        insightPath.fill()

                        // Left border accent
                        blue.setFill()
                        UIRectFill(CGRect(x: margin, y: innerY, width: 3, height: insightBlockH))

                        insightStr.draw(in: CGRect(x: margin + insightIndent, y: innerY + 10,
                                                   width: insightW, height: insightBlockH))
                    }

                    yOffset += totalCardH + 10
                }

                // MARK: Render
                beginPage()
                drawCover()
                drawSectionHeader("Chapter-by-Chapter Core Learnings")
                for learning in learnings {
                    drawLearning(learning)
                }
                pageFooter()
            }
            return tempURL
        } catch {
            return nil
        }
    }

    // Rough page estimate for footer "X of N"
    private static func estimatePageCount(learnings: [Learning], contentWidth: CGFloat, margin: CGFloat, pageSize: CGSize) -> Int {
        let avgCardHeight: CGFloat = 120
        let usableHeight = pageSize.height - 100
        let cardsPerPage = max(1, Int(usableHeight / avgCardHeight))
        return max(1, Int(ceil(Double(learnings.count) / Double(cardsPerPage))))
    }
}

