//
//  ViewController.swift
//  StockMoji
//
//  Created by Jonathan Cheth on 5/14/25.
//

import UIKit
import CoreML

class ViewController: UIViewController {
    
    @IBOutlet var backgroundView: UIView!
    @IBOutlet weak var emojiLabel: UILabel!
    @IBOutlet weak var lookupLabel: UITextField!
    
    let sentimentClassifier = TweetSentimentClassifier()
    let tweetCount = 20
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }

    @IBAction func predictPressed(_ sender: UIButton) {
        guard let keyword = lookupLabel.text, !keyword.isEmpty else {
            emojiLabel.text = "❓"
            return
        }
        fetchTweets(for: keyword)
        view.endEditing(true)
    }
    
    func fetchTweets(for keyword: String) {
         let bearerToken = "YOUR_TWITTER_BEARER_TOKEN_HERE" // Replace this!

         let urlString = "https://api.twitter.com/2/tweets/search/recent?query=\(keyword)&max_results=\(tweetCount)&tweet.fields=text"

         guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
             print("Invalid URL")
             return
         }

         var request = URLRequest(url: url)
         request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

         let task = URLSession.shared.dataTask(with: request) { data, response, error in
             if let error = error {
                 print("Network error: \(error)")
                 return
             }

             guard let data = data else {
                 print("No data received")
                 return
             }

             do {
                 let decoded = try JSONDecoder().decode(TwitterResponse.self, from: data)

                 guard let tweets = decoded.data else {
                     print("No tweets found")
                     DispatchQueue.main.async {
                         self.emojiLabel.text = "😐"
                     }
                     return
                 }

                 let tweetInputs = tweets.map { TweetSentimentClassifierInput(text: $0.text) }
                 self.makePrediction(with: tweetInputs)

             } catch {
                 print("JSON Decode Error: \(error)")
                 if let raw = String(data: data, encoding: .utf8) {
                     print("Raw response: \(raw)")
                 }
             }
         }

         task.resume()
     }

     func makePrediction(with tweets: [TweetSentimentClassifierInput]) {
         do {
             let predictions = try sentimentClassifier.predictions(inputs: tweets)
             let sentimentScore = predictions.reduce(0) { score, pred in
                 switch pred.label {
                 case "Pos": return score + 1
                 case "Neg": return score - 1
                 default: return score
                 }
             }

             DispatchQueue.main.async {
                 self.updateUI(with: sentimentScore)
             }
         } catch {
             print("Prediction error: \(error)")
         }
     }

     func updateUI(with sentimentScore: Int) {
         switch sentimentScore {
         case 10...: emojiLabel.text = "🚀"
         case 5..<10: emojiLabel.text = "😄"
         case 1..<5: emojiLabel.text = "🙂"
         case 0: emojiLabel.text = "😐"
         case (-4)...(-1): emojiLabel.text = "😕"
         case (-9)...(-5): emojiLabel.text = "😡"
         default: emojiLabel.text = "💀"
         }
     }
}

// MARK: - Twitter Response Models
struct TwitterResponse: Codable {
    let data: [Tweet]?
}

struct Tweet: Codable {
    let text: String
}
