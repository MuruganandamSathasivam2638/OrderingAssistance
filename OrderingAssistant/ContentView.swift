import SwiftUI
import Speech
import AVFoundation

// MARK: - Product Models
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let modifiers: [String]
    let quantity: Int?
}

struct MatchedProduct: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let modifiers: [String]?
}

struct GradientBackgroundView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 7/255, green: 9/255, blue: 81/255),   // Dark Blue Top-Left
                Color(red: 11/255, green: 30/255, blue: 129/255), // Mid Blue
                Color(red: 25/255, green: 50/255, blue: 144/255), // Bright Blue
                Color(red: 40/255, green: 45/255, blue: 120/255)  // Deep Purple Bottom-Right
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct GradientBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        GradientBackgroundView()
    }
}

// MARK: - SpeechRecognizer
class SpeechRecognizer: ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcribedText: String = ""

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startRecording() throws {
        transcribedText = ""

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true

        recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

// MARK: - String Matching Extension
extension String {
    func containsPartialWords(from input: String) -> Bool {
        let selfWords = self.lowercased().split(separator: " ")
        for word in selfWords where word.count >= 3 {
            if input.contains(word) {
                return true
            }
        }
        return false
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var matchedProducts: [MatchedProduct] = []
    @State private var cart: [MatchedProduct] = []
    @State private var isVoiceModalPresented = false
    @State private var cartCount: Int = 2

    let products = [
        Product(name: "Wisconsin Mac & Cheese", modifiers: ["extra cheese", "no breadcrumbs", "add parmesan chicken", "spicy", "light cheese", "add bacon", "no sauce"], quantity: 10),
        Product(name: "Penne Rosa", modifiers: ["extra sauce", "add shrimp", "no tomato", "spicy", "light cream", "add grilled chicken", "no mushrooms"], quantity: 10),
        Product(name: "Pad Thai", modifiers: ["add tofu", "no egg", "extra peanuts", "spicy", "no cilantro", "add shrimp", "light sauce"], quantity: 10),
        Product(name: "Japanese Pan Noodles", modifiers: ["extra sauce", "add steak", "no broccoli", "sweet", "add mushrooms", "no onions", "add tofu"], quantity: 10),
        Product(name: "Spaghetti & Meatballs", modifiers: ["extra meatballs", "no cheese", "add parmesan chicken", "light marinara", "spicy", "no garlic", "add mushrooms"], quantity: 10),
        Product(name: "Zucchini Pesto", modifiers: ["no cheese", "add grilled chicken", "extra pesto", "no tomato", "light sauce", "add mushrooms", "gluten free"], quantity: 10),
        Product(name: "Buffalo Chicken Mac", modifiers: ["extra buffalo sauce", "add bacon", "no blue cheese", "spicy", "extra chicken", "no breadcrumbs", "light cheese"], quantity: 10)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                List(products) { product in
                    VStack(alignment: .leading) {
                        Text(product.name).font(.headline)
                        Text("Modifiers: \(product.modifiers.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isVoiceModalPresented = true
                        }) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.darkBlue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                        .accessibilityLabel("Start voice ordering")
                    }
                }
            }
            .navigationTitle("Products")
            .navigationBarItems(trailing:
                    NavigationLink(destination: CartView(cart: $cart)) {
                        ZStack(alignment: .topTrailing) {
                            Image("cart")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(5)
                            
                            if cartCount > 0 {
                                Text("\(cartCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Color.brightMagenta)
                                    .clipShape(Circle())
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
            )
            .sheet(isPresented: $isVoiceModalPresented) {
                VoiceDetectionScreen(
                    isPresented: $isVoiceModalPresented,
                    speechRecognizer: speechRecognizer,
                    matchedProducts: $matchedProducts,
                    cart: $cart,
                    products: products
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Voice Detection Bottom Sheet
struct VoiceDetectionScreen: View {
    @Binding var isPresented: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @Binding var matchedProducts: [MatchedProduct]
    @Binding var cart: [MatchedProduct]
    
    @State private var detectedProducts: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var contextString: String = ""

    let products: [Product]
    @State private var animateMic = false
    
    struct OrderIntent: Decodable {
        let products: [ProductIntent]
    }

    struct ProductIntent: Decodable {
        let product: String
        let modifiers: [String]
        let quantity: Int?
    }

    var body: some View {
        VStack {
            HStack {
                Button("Close") {
                    isPresented = false
                }
                .padding(.leading)
                
                Spacer()
                
                Button("Stop") {
                    speechRecognizer.stopRecording()
                    animateMic = false
                    Task { await processInput(speechRecognizer.transcribedText) }
                }
                .padding(.trailing)
            }
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundColor(animateMic ? .blue : .gray)
                    .frame(width: 70, height: 70)
                    .scaleEffect(animateMic ? 1.3 : 1)
                    .animation(animateMic ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: animateMic)

                Image(systemName: "mic.fill")
                    .foregroundColor(animateMic ? .blue : .gray)
                    .font(.system(size: 30, weight: .bold))
            }
            .padding(.bottom)


            if detectedProducts.isEmpty {
                Text("Say a product name to begin")
                    .foregroundColor(.gray)
                    .padding()
                Text(speechRecognizer.transcribedText)
                    .font(.title3)
                    .padding(.bottom)
            } else {
                Text(contextString.isEmpty ? "" : "You said: \(contextString)")
                    .font(.title3)
                    .padding(.bottom)

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
            }

            Spacer()
        }
        .padding()
        .onAppear {
            detectedProducts = []
            do {
                try speechRecognizer.startRecording()
                animateMic = true
            } catch {
                print("Failed to start recording: \(error)")
            }
            requestPermissions()
        }
        .onDisappear {
            speechRecognizer.stopRecording()
            animateMic = false
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

    private func filterProducts(from input: String) {
        let lowerInput = input.lowercased()
        self.contextString = lowerInput
        matchedProducts = products.compactMap { product in
            guard product.name.lowercased().containsPartialWords(from: lowerInput) else { return nil }
            let matchedMods = product.modifiers.filter { lowerInput.contains($0.lowercased()) }
            return MatchedProduct(name: product.name, modifiers: matchedMods.isEmpty ? nil : matchedMods)
        }
    }
}

// MARK: - Cart Screen
struct CartView: View {
    @Binding var cart: [MatchedProduct]

    var body: some View {
        List {
            ForEach(cart) { item in
                VStack(alignment: .leading) {
                    Text(item.name).bold()
                    if let mods = item.modifiers {
                        Text("Modifiers: \(mods.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Your Cart")
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
