//
//  ViewController+Speech.swift
//  whitespace
//
//  Created by Kevin Hu on 7/19/19.
//  Copyright © 2019 Corey Hu. All rights reserved.
//

import UIKit
import Foundation
import Speech
import SceneKit

extension ViewController: SFSpeechRecognizerDelegate {
    
    override public func viewDidAppear(_ animated: Bool) {
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        
        speechRecognizer.delegate = self
        
        
        // Make the authorization request
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // The authorization status results in changes to the
            // app’s interface, so process the results on the app’s
            // main queue.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                @unknown default:
                    self.recordButton.isEnabled = false
                    fatalError("You hit the unknown error I didn't prepare for! Oops.")
                }
            }
        }
    }
    
    private func startAudioRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.contextualStrings = blacklist
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
        }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                let newWordCount = text.split(separator: " ").count
                // Threshold for wpm measurement
                if newWordCount > 5 {
                    let now = Date()
                    let delta = newWordCount - self.wordCount
                    let wpm = Float(delta) / Float(now.timeIntervalSince(self.lastTextUpdate)) * 60
                    if wpm > 0 && wpm < 300 {
                        self.manager.addSample(wpm, To: .speakingRate)
                        self.wordCount = newWordCount
                        self.lastTextUpdate = now
                    }
                    
                }
                
                var count = 0
                for phrase in self.blacklist {
                    count += text.components(separatedBy: phrase).count - 1
                }
                if count > self.blacklistCount {
                    print("Blacklist")
                    self.manager.addSample(1, To: Metric.blacklistRate)
                    self.manager.beep()
                }
                self.blacklistCount = count
                self.textView.text = text
                isFinal = result.isFinal
            }
            
            if error != nil {
                print("Speech error: \(error!)")
                
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        textView.text = "(Go ahead, I'm listening)"
    }
    
    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("Speech Recognizer availability changed")
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    func toggleRecording() {
        if !isRecording {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startAudioRecording()
            recordButton.setTitle("Stop recording", for: [])
        }
    }
}
