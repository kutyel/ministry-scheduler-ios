//
//  NWPublisherReport.swift
//  iMinistry
//
//  Sends the month-end report to NW Publisher (nwpublisher.com) through
//  its universal report link.
//

import Foundation
import UIKit

/// Submits the report to NW Publisher through its universal link, e.g.
/// `https://nwpublisher.com/report/sharedInMinistry=true:hours=50:credit=17:remarks=bethel+work`.
///
/// Variables are case-sensitive, optional and separated by colons. NW
/// Publisher only accepts the report of the previous month, so the link
/// carries no month or year.
enum NWPublisherIntegration {
    static let reportEndpoint = "https://nwpublisher.com/report/"

    /// Characters allowed unescaped inside a value. The colon delimits
    /// variables, `=` separates names from values and `+` stands for a
    /// space, so all three are escaped when they appear in the text.
    private static let valueAllowed: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: ":=+/")
        return set
    }()

    /// Variables are only sent when they carry a value, as NW Publisher
    /// suggests, rather than sending 0. `credit` must be a whole number, so
    /// it is rounded to the nearest hour; the exact breakdown goes in
    /// `remarks`.
    static func reportURL(for report: MonthlyReport) -> URL {
        var variables: [(String, String)] = []
        if report.fieldServiceMinutes > 0 {
            variables.append(("sharedInMinistry", "true"))
            variables.append(("hours", decimalHours(report.fieldServiceMinutes)))
        }
        if report.creditedMinutes > 0 {
            let creditHours = Int((Double(report.creditedMinutes) / 60.0).rounded())
            if creditHours > 0 {
                variables.append(("credit", String(creditHours)))
            }
            variables.append(("remarks", encodeRemarks(report.creditRemarks)))
        }
        let path = variables.map { "\($0)=\($1)" }.joined(separator: ":")
        return URL(string: reportEndpoint + path)!
    }

    static func submit(_ report: MonthlyReport) {
        UIApplication.shared.open(reportURL(for: report))
    }

    /// Hours as a decimal with at most two places, e.g. "50", "2.5", "1.33".
    static func decimalHours(_ minutes: Int) -> String {
        let hours = (Double(minutes) / 60.0 * 100).rounded() / 100
        return String(format: "%g", hours)
    }

    /// Remarks cannot contain colons and spaces must be written as `+`.
    static func encodeRemarks(_ remarks: String) -> String {
        remarks
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "：", with: " ")
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { $0.addingPercentEncoding(withAllowedCharacters: valueAllowed) ?? "" }
            .joined(separator: "+")
    }
}
