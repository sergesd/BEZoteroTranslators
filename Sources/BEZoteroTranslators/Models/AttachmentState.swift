//
//  AttachmentState.swift
//  BEZoteroTranslators
//
//  Created based on ZShare
//

import Foundation

/// Represents the current state of attachment processing
/// This tracks the progress from initial decoding through final completion
public enum AttachmentState: Sendable {
    /// Initial state - decoding attachment and deciding what to do with it
    case decoding
    
    /// Translation is in progress with a progress message
    case translating(String)
    
    /// Attachment is being downloaded with progress percentage
    case downloading(progress: Double)
    
    /// Processing has completed - waiting for submission
    case processed
    
    /// Submitting processed attachment to backend
    case submitting
    
    /// Sharing was successful - extension should close
    case done
    
    /// Processing failed with an error
    case failed(Error)
}

// MARK: - Convenience Extensions

extension AttachmentState {
    /// Whether the state represents a completed operation
    public var isCompleted: Bool {
        switch self {
        case .done, .failed:
            return true
        case .decoding, .translating, .downloading, .processed, .submitting:
            return false
        }
    }
    
    /// Whether the state represents a failed operation
    public var isFailed: Bool {
        switch self {
        case .failed:
            return true
        case .decoding, .translating, .downloading, .processed, .submitting, .done:
            return false
        }
    }
    
    /// Whether the state represents an in-progress operation
    public var isInProgress: Bool {
        switch self {
        case .translating, .downloading, .submitting:
            return true
        case .decoding, .processed, .done, .failed:
            return false
        }
    }
    
    /// The progress percentage (0.0 to 1.0) for downloading states
    public var progress: Double? {
        switch self {
        case .downloading(let progress):
            return progress
        case .decoding, .translating, .processed, .submitting, .done, .failed:
            return nil
        }
    }
    
    /// The progress message for translating states
    public var progressMessage: String? {
        switch self {
        case .translating(let message):
            return message
        case .decoding, .downloading, .processed, .submitting, .done, .failed:
            return nil
        }
    }
    
    /// The error for failed states
    public var error: Error? {
        switch self {
        case .failed(let error):
            return error
        case .decoding, .translating, .downloading, .processed, .submitting, .done:
            return nil
        }
    }
}

// MARK: - Equatable

extension AttachmentState: Equatable {
    public static func == (lhs: AttachmentState, rhs: AttachmentState) -> Bool {
        switch (lhs, rhs) {
        case (.decoding, .decoding),
             (.processed, .processed),
             (.submitting, .submitting),
             (.done, .done):
            return true
            
        case (.translating(let lhsMessage), .translating(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
            return lhsProgress == rhsProgress
            
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
            
        default:
            return false
        }
    }
}
