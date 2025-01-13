//
//  Logger.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import os

struct AppLogger {
    static let shared = Logger(subsystem: "io.aparker.locol", category: "general")
}
