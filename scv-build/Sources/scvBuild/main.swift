import Foundation

let command = BuildDBCommand()
do {
  try command.run()
} catch {
  print("ERROR: \(error)")
  exit(1)
}
