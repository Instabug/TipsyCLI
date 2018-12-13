import TipsyCore

let tipsy = Tipsy()

do {
    try tipsy.run()
} catch {
    print("Whoops! An error occurred: \(error)")
}
