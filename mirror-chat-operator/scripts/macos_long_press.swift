#!/usr/bin/env swift
import CoreGraphics
import Foundation

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: macos_long_press.swift <x> <y> [duration_ms]\n".utf8))
    exit(2)
}

let args = CommandLine.arguments.dropFirst()
if args.first == "--help" || args.first == "-h" {
    print("usage: macos_long_press.swift <x> <y> [duration_ms]")
    print("Posts a macOS mouse down/up at absolute screen coordinates after holding for duration_ms.")
    exit(0)
}

guard args.count == 2 || args.count == 3,
      let x = Double(args[args.startIndex]),
      let y = Double(args[args.index(after: args.startIndex)]) else {
    usage()
}

let durationMs: UInt32
if args.count == 3 {
    guard let parsed = UInt32(args[args.index(args.startIndex, offsetBy: 2)]) else {
        usage()
    }
    durationMs = parsed
} else {
    durationMs = 900
}

let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)
CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(durationMs * 1000)
CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
