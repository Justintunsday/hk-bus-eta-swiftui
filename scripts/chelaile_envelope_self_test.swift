import Foundation

@main
struct CheLaileEnvelopeSelfTest {
    static func main() throws {
        for status in ["0", "00", "000", "OK", "success", "200"] {
            let body = #"{"jsonr":{"data":{"value":"accepted"},"status":"\#(status)"}}"#
            let payload = try CheLaileClient.decodeEnvelope(body)
            let object = try JSONSerialization.jsonObject(with: payload) as? [String: String]
            precondition(object?["value"] == "accepted", "Success status \(status) was not decoded")
        }

        let failure = #"{"jsonr":{"data":{},"status":"12009","errmsg":"upgrade required"}}"#
        do {
            _ = try CheLaileClient.decodeEnvelope(failure)
            preconditionFailure("A real upstream failure was accepted")
        } catch let error as CheLaileError {
            guard case .upstream(let code, _) = error, code == "12009" else {
                preconditionFailure("Unexpected error mapping: \(error)")
            }
        }

        print("CHELAILE ENVELOPE SELF-TEST OK")
    }
}
