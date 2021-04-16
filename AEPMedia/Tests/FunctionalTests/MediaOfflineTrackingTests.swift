/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
import AEPCore
@testable import AEPMedia

class MediaOfflineTrackingTests: MediaFunctionalTestBase {

    static let config: [String: Any] = [MediaConstants.TrackerConfig.DOWNLOADED_CONTENT: true]
    var tracker: MediaEventGenerator!
    let semaphore = DispatchSemaphore(value: 0)

    override func setUp() {
        super.setupBase()
        tracker = MediaEventGenerator(config: Self.config, dispatch: mockRuntime.dispatch(event:))
    }

    func ignoreTestDownloadedContentSession() {
        // setup
        dispatchDefaultConfigAndSharedStates()
        guard let mediaInfo = Media.createMediaObjectWith(name: "video", id: "videoId", length: 30.0, streamType: "vod", mediaType: MediaType.Video) else {
            XCTFail("failed to create media info")
            return
        }
        let metadata = ["SampleContextData": "SampleValue", "a.media.show": "show"]
        guard let qoeInfo = Media.createQoEObjectWith(bitrate: 1000, startupTime: 2, fps: 14, droppedFrames: 6), let qoeInfo2 = Media.createQoEObjectWith(bitrate: 2000, startupTime: 4, fps: 24, droppedFrames: 33) else {
            XCTFail("failed to create qoe info objects")
            return
        }

        // test
        let sessionStartTs = Int64(0)
        tracker.setTimeStamp(value: sessionStartTs)
        tracker.trackSessionStart(info: mediaInfo, metadata: metadata)
        tracker.updateQoEObject(qoe: qoeInfo)
        tracker.trackPlay()
        tracker.updateCurrentPlayhead(time: 1)
        waitFor(2, updatePlayhead: true, tracker: tracker, semaphore: semaphore)
        semaphore.wait()
        tracker.updateCurrentPlayhead(time: 5)
        tracker.updateQoEObject(qoe: qoeInfo2)
        tracker.trackPause()
        waitFor(51, updatePlayhead: false, tracker: tracker, semaphore: semaphore)
        semaphore.wait()
        tracker.trackPlay()
        tracker.updateCurrentPlayhead(time: 10)
        tracker.trackComplete()
        waitForProcessing()
        // verify
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 1)
        let sessionHit = mockNetworkService?.calledNetworkRequests[0]
        guard let sessionHitData = sessionHit?.connectPayload.data(using: .utf8) else {
            XCTFail("Failed to convert session hit payload to data")
            return
        }
        let payloadAsJson: [[String: Any]]? = try? JSONSerialization.jsonObject(with: sessionHitData, options: []) as? [[String: Any]]
        verifyEvent(eventName: "sessionStart", payload: payloadAsJson?[0] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 0, ts: sessionStartTs, isDownloadedSession: true)
        verifyEvent(eventName: "play", payload: payloadAsJson?[1] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, expectedQoe: qoeInfo, playhead: 0, ts: sessionStartTs, isDownloadedSession: true)
        verifyEvent(eventName: "play", payload: payloadAsJson?[2] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 3, ts: sessionStartTs + 3, isDownloadedSession: true)
        verifyEvent(eventName: "pauseStart", payload: payloadAsJson?[3] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, expectedQoe: qoeInfo2, playhead: 5, ts: sessionStartTs + 4, isDownloadedSession: true)
        verifyEvent(eventName: "ping", payload: payloadAsJson?[4] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 5, ts: sessionStartTs + 54, isDownloadedSession: true)
        verifyEvent(eventName: "play", payload: payloadAsJson?[5] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 5, ts: sessionStartTs + 55, isDownloadedSession: true)
        verifyEvent(eventName: "sessionComplete", payload: payloadAsJson?[6] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 10, ts: sessionStartTs + 55, isDownloadedSession: true)
    }

    func ignoreTestDownloadedContentSessionWhenPrivacyOptedOut() {
        // setup
        dispatchDefaultConfigAndSharedStates(configData: [MediaConstants.Configuration.GLOBAL_CONFIG_PRIVACY: "optedout"])
        guard let mediaInfo = Media.createMediaObjectWith(name: "video", id: "videoId", length: 30.0, streamType: "vod", mediaType: MediaType.Video) else {
            XCTFail("failed to create media info")
            return
        }
        let metadata = ["SampleContextData": "SampleValue", "a.media.show": "show"]

        // test
        let sessionStartTs = Int64(0)
        tracker.setTimeStamp(value: sessionStartTs)
        tracker.trackSessionStart(info: mediaInfo, metadata: metadata)
        tracker.trackComplete()
        waitForProcessing()
        // verify
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
    }

    func ignoreTestDownloadedContentSessionWhenPrivacyUnknown() {
        // setup
        dispatchDefaultConfigAndSharedStates(configData: [MediaConstants.Configuration.GLOBAL_CONFIG_PRIVACY: "unknown"])
        guard let mediaInfo = Media.createMediaObjectWith(name: "video", id: "videoId", length: 30.0, streamType: "vod", mediaType: MediaType.Video) else {
            XCTFail("failed to create media info")
            return
        }
        let metadata = ["SampleContextData": "SampleValue", "a.media.show": "show"]

        // test
        tracker.setTimeStamp(value: 0)
        tracker.trackSessionStart(info: mediaInfo, metadata: metadata)
        tracker.trackComplete()
        waitForProcessing()
        // verify
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 0)
    }

    func ignoretestDownloadedContentSessionRequestRetriedWhenInitialNetworkRequestReceivedConnectionError() {
        // setup
        dispatchDefaultConfigAndSharedStates()
        guard let mediaInfo = Media.createMediaObjectWith(name: "video", id: "videoId", length: 30.0, streamType: "vod", mediaType: MediaType.Video) else {
            XCTFail("failed to create media info")
            return
        }
        let metadata = ["SampleContextData": "SampleValue", "a.media.show": "show"]
        guard let qoeInfo = Media.createQoEObjectWith(bitrate: 1000, startupTime: 2, fps: 14, droppedFrames: 6), let qoeInfo2 = Media.createQoEObjectWith(bitrate: 2000, startupTime: 4, fps: 24, droppedFrames: 33) else {
            XCTFail("failed to create qoe info objects")
            return
        }
        // setup mock network to return a connection error
        mockNetworkService?.shouldReturnConnectionError = true

        // test
        let sessionStartTs = Int64(0)
        tracker.setTimeStamp(value: sessionStartTs)
        tracker.trackSessionStart(info: mediaInfo, metadata: metadata)
        tracker.updateQoEObject(qoe: qoeInfo)
        tracker.trackPlay()
        tracker.updateCurrentPlayhead(time: 1)
        waitFor(2, updatePlayhead: true, tracker: tracker, semaphore: semaphore)
        semaphore.wait()
        tracker.updateCurrentPlayhead(time: 5)
        tracker.updateQoEObject(qoe: qoeInfo2)
        tracker.trackPause()
        waitFor(51, updatePlayhead: false, tracker: tracker, semaphore: semaphore)
        semaphore.wait()
        tracker.trackPlay()
        tracker.updateCurrentPlayhead(time: 10)
        tracker.trackComplete()
        waitForProcessing()
        // setup mock network to return a valid connection and wait 33 seconds for retried request
        mockNetworkService?.shouldReturnConnectionError = false
        sleep(33)
        // verify two session start network requests due to initial session start request getting an error response and the request being retried
        XCTAssertEqual(mockNetworkService?.calledNetworkRequests.count, 2)
        let sessionHit = mockNetworkService?.calledNetworkRequests[1]
        guard let sessionHitData = sessionHit?.connectPayload.data(using: .utf8) else {
            XCTFail("Failed to convert session hit payload to data")
            return
        }
        let payloadAsJson: [[String: Any]]? = try? JSONSerialization.jsonObject(with: sessionHitData, options: []) as? [[String: Any]]
        verifyEvent(eventName: "sessionStart", payload: payloadAsJson?[0] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 0, ts: sessionStartTs, isDownloadedSession: true)
        verifyEvent(eventName: "play", payload: payloadAsJson?[1] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, expectedQoe: qoeInfo, playhead: 0, ts: sessionStartTs, isDownloadedSession: true)
        verifyEvent(eventName: "play", payload: payloadAsJson?[2] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 3, ts: sessionStartTs + 3, isDownloadedSession: true)
        verifyEvent(eventName: "pauseStart", payload: payloadAsJson?[3] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, expectedQoe: qoeInfo2, playhead: 5, ts: sessionStartTs + 4, isDownloadedSession: true)
        verifyEvent(eventName: "ping", payload: payloadAsJson?[4] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 5, ts: sessionStartTs + 54, isDownloadedSession: true)
        verifyEvent(eventName: "play", payload: payloadAsJson?[5] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 5, ts: sessionStartTs + 55, isDownloadedSession: true)
        verifyEvent(eventName: "sessionComplete", payload: payloadAsJson?[6] ?? [:], expectedInfo: mediaInfo, expectedMetadata: metadata, playhead: 10, ts: sessionStartTs + 55, isDownloadedSession: true)
    }

}
