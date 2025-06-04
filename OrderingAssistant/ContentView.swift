import SwiftUI
import Speech
import AVFoundation

// MARK: - Models

struct Product: Identifiable, Decodable {
    let id = UUID()
    let name: String
    let modifiers: [String]
    let quantity: Int?
}

struct ProductIntent: Decodable {
    let product: String
    let modifiers: [String]
    let quantity: Int?
}

struct OrderIntent: Decodable {
    let products: [ProductIntent]
}

// MARK: - Repository

struct ProductRepository {
    static let products = [
        Product(name: "Wisconsin Mac & Cheese", modifiers: ["extra cheese", "no breadcrumbs", "add parmesan chicken"], quantity: 10),
        Product(name: "Penne Rosa", modifiers: ["extra sauce", "add shrimp", "no tomato"], quantity: 10),
        Product(name: "Pad Thai", modifiers: ["add tofu", "no egg", "extra peanuts"], quantity: 10),
        Product(name: "Japanese Pan Noodles", modifiers: ["extra sauce", "add steak", "no broccoli"], quantity: 10),
        Product(name: "Spaghetti & Meatballs", modifiers: ["extra meatballs", "no cheese", "add parmesan chicken"], quantity: 10),
        Product(name: "Zucchini Pesto", modifiers: ["no cheese", "add grilled chicken", "extra pesto"], quantity: 10),
        Product(name: "Buffalo Chicken Mac", modifiers: ["extra buffalo sauce", "add bacon", "no blue cheese"], quantity: 10)
    ]
}

// MARK: - ContentView

struct ContentView: View {
    @State private var isVoiceInputPresented = false
    let allProducts = ProductRepository.products

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(allProducts) { product in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(product.name)
                                        .font(.headline)

                                    Text("Modifiers: \(product.modifiers.joined(separator: ", "))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .shadow(radius: 2)
                        }
                    }
                    .padding()
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isVoiceInputPresented = true
                        }) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Menu")
            .sheet(isPresented: $isVoiceInputPresented) {
                VoiceInputView(isPresented: $isVoiceInputPresented)
            }
        }
    }
}

// MARK: - VoiceInputView

struct VoiceInputView: View {
    @Binding var isPresented: Bool
    @State private var userInput = ""
    @State private var detectedProducts: [Product] = []
    @State private var isListening = false
    @State private var isProcessing = false
    @State private var micPulse = false
    @State private var brainPulse = false

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioSession = AVAudioSession.sharedInstance()
    @State private var recognitionTask: SFSpeechRecognitionTask?

    let allProducts = ProductRepository.products

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isListening {
                    statusView(label: "Listening...", icon: "mic.fill", color: .blue, pulse: micPulse)
                } else if isProcessing {
                    statusView(label: "Processing...", icon: "cpu.fill", color: .green, pulse: brainPulse)
                }

                if !userInput.isEmpty {
                    Text(userInput)
                        .font(.body)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                if !detectedProducts.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🛒 Detected Products")
                            .font(.headline)

                        ForEach(detectedProducts) { product in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name).font(.title3.bold())
                                ForEach(product.modifiers, id: \.self) {
                                    Text("• \($0)").foregroundColor(.gray)
                                }
                                Text("Quantity: \(product.quantity ?? 1)").font(.subheadline)
                                Divider().padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                } else if !isListening && !isProcessing {
                    Text("No products detected.")
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Close") {
                    isPresented = false
                }
                .padding(.bottom)
            }
            .padding()
            .onAppear(perform: startListening)
            .onDisappear(perform: stopListening)
            .navigationTitle("Voice Order")
            .navigationBarHidden(true)
        }
    }

    // MARK: - Views

    func statusView(label: String, icon: String, color: Color, pulse: Bool) -> some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.headline)
                .foregroundColor(color)

            ZStack {
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundColor(color)
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulse ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 1), value: pulse)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 30, weight: .bold))
            }
        }
    }

    // MARK: - Speech Recognition

    func startListening() {
        isListening = true
        startPulse(for: .mic)

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                print("Speech recognition not authorized")
                return
            }

            do {
                try audioSession.setCategory(.record, mode: .measurement)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true

                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    request.append(buffer)
                }

                audioEngine.prepare()
                try audioEngine.start()

                recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
                    if let result = result {
                        userInput = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        stopListening()
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    stopListening()
                }

            } catch {
                print("Speech setup failed: \(error)")
                stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isListening = false
        isProcessing = true
        startPulse(for: .brain)

        Task {
            await processInput(userInput)
        }
    }

    enum PulseType { case mic, brain }

    func startPulse(for type: PulseType) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            switch type {
            case .mic:
                if isListening { micPulse.toggle() } else { timer.invalidate() }
            case .brain:
                if isProcessing { brainPulse.toggle() } else { timer.invalidate() }
            }
        }
    }

    // MARK: - OpenAI Integration

    func processInput(_ input: String) async {
        let prompt = """
        You are a voice ordering assistant. Extract products, modifiers, and quantities from the text.

        Menu:
        \(allProducts.map { "- \($0.name): \($0.modifiers.joined(separator: ", "))" }.joined(separator: "\n"))

        User said: "\(input)"

        Format:
        {
          "products": [
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

            detectedProducts = decoded.products.compactMap { intent in
                if let match = allProducts.first(where: { $0.name.lowercased() == intent.product.lowercased() }) {
                    return Product(name: match.name, modifiers: intent.modifiers, quantity: intent.quantity ?? 1)
                } else {
                    return Product(name: intent.product, modifiers: intent.modifiers, quantity: intent.quantity ?? 1)
                }
            }
        } catch {
            print("OpenAI error: \(error)")
        }

        isProcessing = false
    }

    func callOpenAI(with prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as! String

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        return message?["content"] as? String ?? ""
    }
}
