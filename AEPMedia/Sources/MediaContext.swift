/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing software distributed under
 the License is distributed on an "AS IS" BASIS WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPServices

class MediaContext {
    enum MediaPlaybackState: String {
        case Play
        case Pause
        case Buffer
        case Seek
        case Init
    }

    private static let LOG_TAG = "MediaContext"
    private(set) var buffering = false
    private(set) var seeking = false
    private var trackedStates: [String: Bool] = [:]
    private var playState = MediaPlaybackState.Init

    let mediaInfo: MediaInfo
    let mediaMetadata: [String: String]

    private(set) var adBreakInfo: AdBreakInfo?
    private(set) var adInfo: AdInfo?
    private(set) var adMetadata: [String: String] = [:]

    private(set) var chapterInfo: ChapterInfo?
    private(set) var chapterMetadata: [String: String] = [:]

    private(set) var errorInfo: [String: String]?

    var playhead = 0.0
    var qoeInfo: QoEInfo?

    init(mediaInfo: MediaInfo, metadata: [String: String]?) {
        self.mediaInfo = mediaInfo
        self.mediaMetadata = metadata ?? [:]
    }

    // AdBreak
    func setAdBreak(info: AdBreakInfo) {
        adBreakInfo = info
    }

    func clearAdBreak() {
        adBreakInfo = nil
    }

    // Ad
    func setAd(info: AdInfo, metadata: [String: String]) {
        adInfo = info
        adMetadata = metadata
    }

    func clearAd() {
        adInfo = nil
        adMetadata = [:]
    }

    // Chapter
    func setChapter(info: ChapterInfo, metadata: [String: String]) {
        chapterInfo = info
        chapterMetadata = metadata
    }

    func clearChapter() {
        chapterInfo = nil
        chapterMetadata = [:]
    }

    func enterPlaybackState(state: MediaPlaybackState) {
        Log.trace(label: Self.LOG_TAG, "\(#function) EnterState - \(state)")
        switch state {
        case .Play, .Pause:
            playState = state
        case .Buffer:
            buffering = true
        case .Seek:
            seeking = true
        default:
            Log.debug(label: Self.LOG_TAG, "\(#function) - Invalid state passed to enterState: \(state)")
        }
    }

    func exitPlaybackState(state: MediaPlaybackState) {
        Log.trace(label: Self.LOG_TAG, "\(#function) ExitState - \(state)")
        switch state {
        case .Buffer:
            buffering = false
        case .Seek:
            seeking = false
        default:
            Log.debug(label: Self.LOG_TAG, "\(#function) - Invalid state passed to exitState: \(state)")
        }
    }

    func isInMediaPlaybackState(state: MediaPlaybackState) -> Bool {
        var retVal = false

        switch state {
        case .Init, .Play, .Pause:
            retVal = (playState == state)
        case .Buffer:
            retVal = buffering
        case .Seek:
            retVal = seeking
        }
        return retVal
    }

    func isIdle() -> Bool {
        return !isInMediaPlaybackState(state: .Play) ||
            isInMediaPlaybackState(state: .Seek) ||
            isInMediaPlaybackState(state: .Buffer)
    }

    // State
    @discardableResult
    func startState(info: StateInfo) -> Bool {
        if !hasTrackedState(info: info) && didReachMaxStateLimit() {
            Log.debug(label: Self.LOG_TAG, "\(#function) - failed, already tracked max states \(MediaConstants.StateInfo.STATE_LIMIT) during the current session.")
            return false
        }

        if isInState(info: info) {
            Log.debug(label: Self.LOG_TAG, "\(#function) - failed, state \(info.stateName) is already being tracked.")
            return false
        }

        trackedStates[info.stateName] = true
        return true
    }

    @discardableResult
    func endState(info: StateInfo) -> Bool {
        if !isInState(info: info) {
            Log.debug(label: Self.LOG_TAG, "\(#function) - failed, state \(info.stateName) is not being tracked.")
            return false
        }

        trackedStates[info.stateName] = false
        return true
    }

    func isInState(info: StateInfo) -> Bool {
        return trackedStates[info.stateName] ?? false
    }

    func hasTrackedState(info: StateInfo) -> Bool {
        return trackedStates[info.stateName] != nil
    }

    func getActiveTrackedStates() -> [StateInfo] {
        var activeStates: [StateInfo] = []

        for (name, active) in trackedStates {
            if active {
                if let stateInfo = StateInfo(stateName: name) {
                    activeStates.append(stateInfo)
                }
            }
        }

        return activeStates
    }

    func didReachMaxStateLimit() -> Bool {
        return trackedStates.count >= MediaConstants.StateInfo.STATE_LIMIT
    }

    func clearStates() {
        trackedStates.removeAll()
    }
}