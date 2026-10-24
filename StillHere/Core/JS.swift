import Foundation

// Small helpers so the story reads the same as the web version it was ported from.
// Every number in the story is a Double, like in JavaScript.

private func cosine(_ x: Double) -> Double { cos(x) }
private func sine(_ x: Double) -> Double { sin(x) }
private func roundDown(_ x: Double) -> Double { x.rounded(.down) }

enum Math {
    static let PI = Double.pi
    static func random() -> Double { Double.random(in: 0..<1) }
    static func cos(_ x: Double) -> Double { cosine(x) }
    static func sin(_ x: Double) -> Double { sine(x) }
    static func abs(_ x: Double) -> Double { Swift.abs(x) }
    static func floor(_ x: Double) -> Double { roundDown(x) }
    static func round(_ x: Double) -> Double { x.rounded() }
    static func max(_ a: Double, _ b: Double) -> Double { Swift.max(a, b) }
    static func min(_ a: Double, _ b: Double) -> Double { Swift.min(a, b) }
}

func % (a: Double, b: Double) -> Double { a.truncatingRemainder(dividingBy: b) }

/// JavaScript-style number to text: 50 not 50.0.
func str(_ v: Double) -> String {
    if v == v.rounded() && Swift.abs(v) < 1e15 { return String(Int(v)) }
    return String(v)
}
func str(_ v: Int) -> String { String(v) }
func str(_ v: String) -> String { v }

/// 0, 1, 2 ... n-1 as Doubles, for `for (let i = 0; i < n; i++)`.
func upTo(_ n: Double) -> [Double] {
    var out: [Double] = []
    var i = 0.0
    while i < n { out.append(i); i += 1 }
    return out
}

func pick<T>(_ arr: [T]) -> T { arr[Int(Math.floor(Math.random() * Double(arr.count)))] }
func shuffle<T>(_ arr: [T]) -> [T] { arr.shuffled() }

extension Array {
    var length: Double { Double(count) }
    subscript(i: Double) -> Element {
        get { self[Int(i)] }
        set { self[Int(i)] = newValue }
    }
    mutating func push(_ e: Element) { append(e) }
    mutating func unshift(_ e: Element) { insert(e, at: 0) }
    func slice(_ a: Double, _ b: Double? = nil) -> [Element] {
        let lo = Swift.max(0, Swift.min(count, Int(a)))
        let hi = b.map { Swift.max(lo, Swift.min(count, Int($0))) } ?? count
        return Array(self[lo..<hi])
    }
    func concat(_ o: [Element]) -> [Element] { self + o }
    func forEachI(_ f: (Element, Double) -> Void) { for (i, e) in enumerated() { f(e, Double(i)) } }
    func mapI<T>(_ f: (Element, Double) -> T) -> [T] { enumerated().map { f($0.element, Double($0.offset)) } }
}
extension Array where Element: Equatable {
    func includes(_ e: Element) -> Bool { contains(e) }
}
extension Array where Element == String {
    func join(_ s: String) -> String { joined(separator: s) }
}
extension String {
    /// "river" -> "River"
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// A dictionary whose lookups don't return optionals, like a JS object of constants.
struct Lookup<V>: ExpressibleByDictionaryLiteral {
    private var d: [String: V]
    init(dictionaryLiteral elements: (String, V)...) { d = Dictionary(uniqueKeysWithValues: elements) }
    subscript(k: String) -> V { d[k]! }
    func has(_ k: String) -> Bool { d[k] != nil }
}

/// Options for sounds, in any order, like the `{ x: 1, z: -2 }` objects in the web version.
/// x: + right / - left, y: up, z: - in front / + behind. Units are roughly metres.
enum O {
    case x(Double), y(Double), z(Double)
    case gain(Double), rate(Double), delay(Double), lowpass(Double)
    case phone(Bool), loop(Bool), keep(Bool)
    case to(Double, Double, Double), toSec(Double)
    // tones
    case type(String), f(Double), f2(Double), dur(Double), attack(Double)
    // footsteps
    case from(Double, Double, Double), gap(Double)
}

struct Opts {
    var x: Double? = nil, y: Double? = nil, z: Double? = nil
    var gain: Double? = nil, rate: Double? = nil, delay: Double? = nil, lowpass: Double? = nil
    var phone = false, loop = false, keep = false
    var to: [Double]? = nil, toSec: Double? = nil
    var type: String? = nil, f: Double? = nil, f2: Double? = nil, dur: Double? = nil, attack: Double? = nil
    var from: [Double]? = nil, gap: Double? = nil

    init(_ list: [O]) {
        for o in list {
            switch o {
            case .x(let v): x = v
            case .y(let v): y = v
            case .z(let v): z = v
            case .gain(let v): gain = v
            case .rate(let v): rate = v
            case .delay(let v): delay = v
            case .lowpass(let v): lowpass = v
            case .phone(let v): phone = v
            case .loop(let v): loop = v
            case .keep(let v): keep = v
            case .to(let a, let b, let c): to = [a, b, c]
            case .toSec(let v): toSec = v
            case .type(let v): type = v
            case .f(let v): f = v
            case .f2(let v): f2 = v
            case .dur(let v): dur = v
            case .attack(let v): attack = v
            case .from(let a, let b, let c): from = [a, b, c]
            case .gap(let v): gap = v
            }
        }
    }
}
