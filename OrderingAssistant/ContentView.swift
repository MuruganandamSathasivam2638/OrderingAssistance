import SwiftUI
import Speech
import AVFoundation

// MARK: - Models

struct Product: Identifiable {
    let id = UUID()
    let name: String
    let modifiers: [String]
    let quantity: Int?
}

struct OrderIntent: Decodable {
    let products: [ProductIntent]
}

struct ProductIntent: Decodable {
    let product: String
    let modifiers: [String]
    let quantity: Int?
}

// MARK: - Product Data

let products = [
    Product(name: "Wisconsin Mac & Cheese", modifiers: ["extra cheese", "no breadcrumbs", "add parmesan chicken", "spicy", "light cheese", "add bacon", "no sauce"], quantity: 10),
    Product(name: "Penne Rosa", modifiers: ["extra sauce", "add shrimp", "no tomato", "spicy", "light cream", "add grilled chicken", "no mushrooms"], quantity: 10),
    Product(name: "Pad Thai", modifiers: ["add tofu", "no egg", "extra peanuts", "spicy", "no cilantro", "add shrimp", "light sauce"], quantity: 10),
    Product(name: "Japanese Pan Noodles", modifiers: ["extra sauce", "add steak", "no broccoli", "sweet", "add mushrooms", "no onions", "add tofu"], quantity: 10),
    Product(name: "Spaghetti & Meatballs", modifiers: ["extra meatballs", "no cheese", "add parmesan chicken", "light marinara", "spicy", "no garlic", "add mushrooms"], quantity: 10),
    Product(name: "Zucchini Pesto", modifiers: ["no cheese", "add grilled chicken", "extra pesto", "no tomato", "light sauce", "add mushrooms", "gluten free"], quantity: 10),
    Product(name: "Buffalo Chicken Mac", modifiers: ["extra buffalo sauce", "add bacon", "no blue cheese", "spicy", "extra chicken", "no breadcrumbs", "light cheese"], quantity: 10)
]

// MARK: - View

struct ContentView: View {
    @State private var userInput = ""
    @State private var detectedProducts: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var audioSession = AVAudioSession.sharedInstance()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Input:")
                Text("\(userInput)")
                    .multilineTextAlignment(.leading)

                Button(action: {
                    Task { await processInput(userInput) }
                }) {
                    HStack {
                        if isLoading { ProgressView() }
                        Text("Detect Products")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .buttonStyle(.borderedProminent)

                // Speech Recognition Button
                Button(action: {
                    startListening()
                }) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Start Listening")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()

                // Display Detected Products
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(detectedProducts) { product in
                        Text(product.name)
                            .font(.title2)
                            .bold()
                        ForEach(product.modifiers, id: \.self) { mod in
                            Text("• \(mod)")
                        }
                        Text("Quantity: \(product.quantity ?? 0)")
                            .font(.title2)
                            .bold()
                        Divider()
                    }
                }
                .padding()

                if let errorMessage = errorMessage {
                    Text("❌ \(errorMessage)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Voice Ordering")
        }
        .onAppear {
            requestPermissions()
        }
    }

    // MARK: - Processing

    func processInput(_ input: String) async {
        isLoading = true
        detectedProducts = []
        errorMessage = nil

        let prompt = """
        You are a helpful assistant for a voice ordering app. Detect the products and their custom modifiers from the user's voice input. 

        Available products with modifiers:
        - Wisconsin Mac & Cheese: [extra cheese, no breadcrumbs, add parmesan chicken, spicy, light cheese, add bacon, no sauce], 10 Quantities
        - Penne Rosa: [extra sauce, add shrimp, no tomato, spicy, light cream, add grilled chicken, no mushrooms], 10 Quantities
        - Pad Thai: [add tofu, no egg, extra peanuts, spicy, no cilantro, add shrimp, light sauce], 10 Quantities
        - Japanese Pan Noodles: [extra sauce, add steak, no broccoli, sweet, add mushrooms, no onions, add tofu], 10 Quantities
        - Spaghetti & Meatballs: [extra meatballs, no cheese, add parmesan chicken, light marinara, spicy, no garlic, add mushrooms], 10 Quantities
        - Zucchini Pesto: [no cheese, add grilled chicken, extra pesto, no tomato, light sauce, add mushrooms, gluten free], 10 Quantities
        - Buffalo Chicken Mac: [extra buffalo sauce, add bacon, no blue cheese, spicy, extra chicken, no breadcrumbs, light cheese], 10 Quantities

        User said: "\(input)"

        Please return a JSON in the following format:
        {
          "products": [
            {
              "product": "<product name>",
              "modifiers": ["<modifier1>", "<modifier2>"],
              "quantity": 0
            },
            {
              "product": "<product name>",
              "modifiers": ["<modifier1>", "<modifier2>"],
              "quantity": 0
            }
          ]
        }
        """

        do {
            let response = try await callOpenAI(with: prompt)
            let decoded = try JSONDecoder().decode(OrderIntent.self, from: Data(response.utf8))

            // Process multiple products detected
            detectedProducts = decoded.products.compactMap { intent in
                if let matchedProduct = products.first(where: { $0.name.lowercased() == intent.product.lowercased() }) {
                    return Product(name: matchedProduct.name, modifiers: intent.modifiers, quantity: intent.quantity)
                } else {
                    // If no exact match, return a generic product
                    return Product(name: intent.product, modifiers: intent.modifiers, quantity: 1)
                }
            }
        } catch {
            errorMessage = "Failed to process input: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - OpenAI API

    func callOpenAI(with prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer API-KEY", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String ?? ""

        return content
    }

    // MARK: - Speech Recognition

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized")
            case .denied:
                print("Speech recognition denied")
            case .restricted:
                print("Speech recognition restricted")
            case .notDetermined:
                print("Speech recognition not determined")
            @unknown default:
                break
            }
        }
    }

    func startListening() {
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            let inputNode = audioEngine.inputNode
            request.shouldReportPartialResults = true

            recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
                if let result = result {
                    self.userInput = result.bestTranscription.formattedString
                }
                if let error = error {
                    print("Error during recognition: \(error.localizedDescription)")
                }
            })

            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { (buffer, when) in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Audio setup failed: \(error.localizedDescription)")
        }
    }
}
