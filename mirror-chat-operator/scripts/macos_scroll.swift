#!/usr/bin/env swift
import CoreGraphics
import Foundation

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: macos_scroll.swift <x> <y> <wheel_delta> [repeats] [delay_ms]\n".utf8))
    exit(2)
}

let args = CommandLine.arguments.dropFirst()
if args.first == "--help" || args.first == "-h" {
    print("usage: macos_scroll.swift <x> <y> <wheel_delta> [repeats] [delay_ms]")
    print("Moves the pointer to absolute screen coordinates and posts repeated macOS scroll wheel events.")
    exit(0)
}

guard args.count >= 3 && args.count <= 5,
      let x = Double(args[args.startIndex]),
      let y = Double(args[args.index(after: args.startIndex)]),
      let delta = Int32(args[args.index(args.startIndex, offsetBy: 2)]) else {
    usage()
}

let repeats: Int
if args.count >= 4 {
    guard let parsed = Int(args[args.index(args.startIndex, offsetBy: 3)]), parsed > 0 else {
        usage()
    }
    repeats = parsed
} else {
    repeats = 12
}

let delayMs: UInt32
if args.count == 5 {
    guard let parsed = UInt32(args[args.index(args.startIndex, offsetBy: 4)]) else {
        usage()
    }
    delayMs = parsed
} else {
    delayMs = 40
}

let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)
CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100_000)

for _ in 0..<repeats {
    CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    usleep(delayMs * 1000)
}
