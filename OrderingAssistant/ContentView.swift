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

class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🗣️ Finished speaking: \(utterance.speechString)")
        onFinish?()
    }
}

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    let synthesizer = AVSpeechSynthesizer()
    var onFinish: (() -> Void)?
    override init() {
        super.init()
        synthesizer.delegate = self // Important for monitoring speech status
    }

    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Optional: set voice
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            print("Speech stopped immediately.")
        } else {
            print("Synthesizer is not speaking.")
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate (Optional but recommended for debugging)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Speech finished: \(utterance.speechString)")
        onFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Speech cancelled: \(utterance.speechString)")
    }
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
    
    var detectedProducts: [Product]

}

// MARK: - ContentView

struct ContentView: View {
    @State private var isVoiceInputPresented = false
    let allProducts = ProductRepository.products
    @State var cartProducts: [Product]
    @State private var activeView: ActiveView = .none
    enum ActiveView {
        case none
        case cart
        case voice
    }

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
                                activeView = .voice
                                isVoiceInputPresented = true
                            }) {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.darkBlue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding()
                        }
                    }
                }
                .navigationBarItems(trailing:
                    Button(action: {
                        activeView = .cart
                    }) {
                        Text("Cart (\(cartProducts.count))")
                    }
                )
                .navigationTitle("Menu")
                .background(
                    NavigationLink(
                        destination: CartView(cartProducts: $cartProducts, openVoice: {
                            activeView = .voice
                            isVoiceInputPresented = true
                        }),
                        isActive: Binding(
                            get: { activeView == .cart },
                            set: { if !$0 { activeView = .none } }
                        )
                    ) { EmptyView() }
                )
                .sheet(isPresented: $isVoiceInputPresented) {
                    VoiceInputView(
                        isPresented: $isVoiceInputPresented,
                        cartProducts: $cartProducts,
                        openCart: {
                            activeView = .cart
                            isVoiceInputPresented = false
                        }
                    )
                }
            }
        }
}

// MARK: - Cart Screen
struct CartView: View {
    @Binding var cartProducts: [Product]
    let openVoice: () -> Void
    var body: some View {
        VStack{
            List {
                ForEach(cartProducts) { product in
                    VStack(alignment: .leading) {
                        Text(product.name).bold()
                        if(!product.modifiers.isEmpty){
                            Text("Modifiers: \(product.modifiers.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Your Cart")
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        openVoice()
                    }) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.darkBlue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }.background(Color(UIColor.systemGroupedBackground))
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
    @State private var isAnnouncing = false

    @Binding var cartProducts: [Product]

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioSession = AVAudioSession.sharedInstance()
    private let PRODUCT_ADDED_TO_CART = "Product added to cart:"
    private let PRODUCT_WITH_MODIFIERS = "with: "
    private let ADD_MORE_PRODUCTS = "Do you want to add more products? Tap the microphone to continue."
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @StateObject private var speechManager = SpeechManager()
    let allProducts = ProductRepository.products
    let openCart: () -> Void
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: {
                            stopAnnouncement()
                            isPresented = false
                        }){
                            Image(systemName: "xmark")
                                .foregroundColor(Color.black)
                                .padding()
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
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
                }  else if isListening {
                    Spacer()
                    Text("Say something delicious...").foregroundColor(.secondary)
                    Spacer()
                }  else if isProcessing {
                    Spacer()
                    Text("Almost there! \nPreparing your favorite bite in the queue...").foregroundColor(.secondary)
                    Spacer()
                } else if !isListening && !isProcessing {
                    Text("No Products detected, Please try again!").foregroundColor(.secondary)
                }

                Spacer()
                
                if !userInput.isEmpty {
                    Text(userInput)
                        .font(.body)
                        .italic()
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                if isListening {
                    LottieView(animationName: "listening").frame(width: 200, height: 200)
                } else if isProcessing {
                    LottieView(animationName: "processing").frame(width: 150, height: 150)
                } else if isAnnouncing {
                    LottieView(animationName: "announcing").frame(width: 100, height: 100)
                } else {
                    Button(action: {
                        startListening()
                    }) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.darkBlue)
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                }
                
            }
            .onChange(of: isProcessing) {
                if !isProcessing {
                    cartProducts.append(contentsOf: detectedProducts)
                    if(!detectedProducts.isEmpty){
                        announceProducts()
                    } else {
                        announce(announcementText: "No Products detected, Please try again!")
                    }
                }
            }
            .padding()
            .onAppear(perform: startListening)
            .navigationTitle("Voice Order")
            .navigationBarHidden(true)
            .onDisappear(perform: onClose)
        }
    }
    
    private func onClose() {
        if(isListening){
            stopListening()
        }
        stopAnnouncement()
    }
    
    private func announceProducts() {
        guard !detectedProducts.isEmpty else { return }

        var announcementText = PRODUCT_ADDED_TO_CART + " "
        
        for product in detectedProducts {
            let quantity = product.quantity ?? 1
            announcementText += "\(quantity) quantity of \(product.name)"
            
            if !product.modifiers.isEmpty {
                let modifierText = product.modifiers.joined(separator: ", ")
                announcementText += " \(PRODUCT_WITH_MODIFIERS) \(modifierText)"
            }
            
            announcementText += ". "  // Add pause between products
        }
        announcementText += ADD_MORE_PRODUCTS
        announce(announcementText: announcementText)
    }

    private func announce(announcementText: String){
        isAnnouncing = true
        speechManager.speak(text: announcementText)
        speechManager.synthesizer.delegate = speechManager
        speechManager.onFinish = {
            isAnnouncing = false
            userInput = ""
            //Redirect to cart screen
            if(!detectedProducts.isEmpty) {
                stopAnnouncement()
                isPresented = false
                openCart()
            }
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
        stopAnnouncement()
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

                inputNode.installTap(onBus: 0, bufferSize: 15000, format: recordingFormat) { buffer, _ in
                    request.append(buffer)
                }

                audioEngine.prepare()
                try audioEngine.start()

                recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
                    if let result = result {
                        userInput = result.bestTranscription.formattedString
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    stopListening()
                }

            } catch {
                print("Speech setup failed: \(error)")
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isListening = false
        isProcessing = true
        let inputText = userInput
        userInput = "Almost there! \nPreparing your favorite bite in the queue..."
        startPulse(for: .brain)

        Task {
            await processInput(inputText)
        }
    }
    
    private func stopAnnouncement() {
        isAnnouncing = false
        speechManager.stop()
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
            print("decoded.products: \(decoded.products)")
            // Filter only recognized products
            detectedProducts = decoded.products.compactMap { intent in
                if let match = allProducts.first(where: { $0.name.lowercased() == intent.product.lowercased() }) {
                    return Product(name: match.name, modifiers: intent.modifiers, quantity: intent.quantity ?? 1)
                } else {
                    return nil // Ignore unrecognized products
                }
            }
            isProcessing = false
        } catch {
            print("OpenAI error: \(error)")
            isProcessing = false
        }
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
