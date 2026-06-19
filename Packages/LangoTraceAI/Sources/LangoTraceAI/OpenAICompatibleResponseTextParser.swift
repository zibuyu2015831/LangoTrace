import Foundation

/// Shared output text extraction for OpenAI-compatible Chat Completions and
/// Responses API payloads.
///
/// Reasoning models prepend `reasoning` items to the Responses `output` array,
/// so parsers must iterate every output item and collect only `output_text`
/// content instead of reading `output.first` directly. Content items without a
/// `type` field are treated as output text for compatibility with providers
/// that omit it.
enum OpenAICompatibleResponseTextParser {
    static func chatCompletionsText(fromResponseObject object: [String: Any]) -> String? {
        guard let choices = object["choices"] as? [[String: Any]] else {
            return nil
        }
        let chunks = choices.compactMap { choice in
            (choice["message"] as? [String: Any])?["content"] as? String
        }
        guard !chunks.isEmpty else {
            return nil
        }
        return chunks.joined(separator: "\n")
    }

    static func responsesText(fromResponseObject object: [String: Any]) -> String? {
        if let outputText = object["output_text"] as? String {
            return outputText
        }
        guard let output = object["output"] as? [[String: Any]] else {
            return nil
        }
        var chunks: [String] = []
        for outputItem in output {
            if let itemType = outputItem["type"] as? String, itemType != "message" {
                continue
            }
            guard let content = outputItem["content"] as? [[String: Any]] else {
                continue
            }
            for contentItem in content {
                if let contentType = contentItem["type"] as? String, contentType != "output_text" {
                    continue
                }
                if let text = contentItem["text"] as? String {
                    chunks.append(text)
                }
            }
        }
        guard !chunks.isEmpty else {
            return nil
        }
        return chunks.joined(separator: "\n")
    }
}
