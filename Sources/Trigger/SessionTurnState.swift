import Foundation

struct SessionTurnStatus: Equatable {
    let isDone: Bool
    let key: String?
}

enum SessionTurnState {
    static func claude(_ lines: [String]) -> SessionTurnStatus {
        for line in lines.reversed() {
            guard let object = json(line), let type = object["type"] as? String else { continue }
            switch type {
            case "assistant":
                let stop = (object["message"] as? [String: Any])?["stop_reason"] as? String
                return SessionTurnStatus(
                    isDone: ["end_turn", "stop_sequence", "stop"].contains(stop ?? ""),
                    key: key(object, fallback: line)
                )
            case "user":
                return SessionTurnStatus(isDone: false, key: key(object, fallback: line))
            default:
                continue
            }
        }
        return SessionTurnStatus(isDone: false, key: nil)
    }

    static func codex(_ lines: [String]) -> SessionTurnStatus {
        for line in lines.reversed() {
            guard let object = json(line) else { continue }
            let type = object["type"] as? String
            let payload = object["payload"] as? [String: Any]
            let payloadType = payload?["type"] as? String
            if type == "event_msg" {
                if isCodexUserOrStart(payloadType) {
                    return SessionTurnStatus(isDone: false, key: key(object, fallback: line))
                }
                if payloadType == "task_complete" || payloadType == "turn/completed" {
                    return SessionTurnStatus(isDone: true, key: key(object, fallback: line))
                }
            }
            if type == "response_item" {
                if payloadType == "message", payload?["role"] as? String == "user" {
                    return SessionTurnStatus(isDone: false, key: key(object, fallback: line))
                }
            }
        }
        return SessionTurnStatus(isDone: false, key: nil)
    }

    private static func isCodexUserOrStart(_ type: String?) -> Bool {
        guard let type else { return false }
        return type == "task_started"
            || type == "turn/started"
            || type == "user_message"
            || type.hasSuffix("/task_started")
            || type.hasSuffix("/user_message")
    }

    private static func key(_ object: [String: Any], fallback line: String) -> String {
        if let uuid = object["uuid"] as? String, !uuid.isEmpty { return uuid }
        if let id = object["id"] as? String, !id.isEmpty { return id }
        if let payload = object["payload"] as? [String: Any] {
            for field in ["turn_id", "id", "item_id", "call_id"] {
                if let value = payload[field] as? String, !value.isEmpty { return value }
            }
        }
        guard let data = line.data(using: .utf8) else { return String(line.prefix(120)) }
        return String(data.base64EncodedString().prefix(160))
    }

    private static func json(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
