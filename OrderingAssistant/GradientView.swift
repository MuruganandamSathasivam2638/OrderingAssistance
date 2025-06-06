//
//  GradientView.swift
//  OrderingAssistant
//
//  Created by Muruganandam Sathasivam on 06/06/25.
//

import UIKit

class GradientView: UIView {
    
    private let gradientLayer = CAGradientLayer()
    
    // Customize these as needed
    var startColor: UIColor = .darkBlue {
        didSet { updateColors() }
    }
    var endColor: UIColor = .brightMagenta {
        didSet { updateColors() }
    }
    
    var startPoint: CGPoint = CGPoint(x: 0, y: 0) {
        didSet { gradientLayer.startPoint = startPoint }
    }
    
    var endPoint: CGPoint = CGPoint(x: 1, y: 1) {
        didSet { gradientLayer.endPoint = endPoint }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        gradientLayer.frame = bounds
        layer.insertSublayer(gradientLayer, at: 0)
        updateColors()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    private func updateColors() {
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
    }
}
