//
//  ContentView.swift
//  VisionLift
//
//  Created by 凌嘉徽 on 2024/7/31.
//

import SwiftUI
import RealityKit
import Vision


struct ImageLiftView: View {
    @State
    var vm = LiftVM()
    var body: some View {
        VStack {
            Image(uiImage:vm.rawImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(32)
                .offset(z: 10)
                .shadow(radius: 13)
                .overlay(alignment: .center, content: {
                    if let processedImage = vm.processedImage {
                        Image(uiImage:processedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .offset(z: 10)
                            .shadow(radius: 13)
                    }
                })
                .beButton {
                    Task {
                        do {
                            try await vm.process()
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                }
                .buttonStyle(.plain)
        }
        .padding(40)
       
    }
}



@MainActor
@Observable
class LiftVM {
    var rawImage:UIImage = UIImage(systemName: "swift")!
    var processedImage:UIImage? = nil
    func process() async throws {
        let res = try await self.getSubject(from: rawImage)
        withAnimation(.smooth) {
            self.processedImage = res
        }
    }
    
    enum ImageSaveError: Error {
        case failedToSaveImage
    }

    func saveImageToTempURL(image: UIImage) throws -> URL {
        // 获取临时目录的URL
        let tempDirectoryURL = FileManager.default.temporaryDirectory
        // 创建临时文件的URL
        let tempFileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")

        // 将UIImage转换为JPEG格式的数据
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            throw ImageSaveError.failedToSaveImage
        }

        do {
            // 尝试将数据写入临时文件
            try imageData.write(to: tempFileURL)
        } catch {
            // 如果写入失败，抛出错误
            throw ImageSaveError.failedToSaveImage
        }

        // 返回临时文件的URL
        return tempFileURL
    }
    
        let request = VNGenerateForegroundInstanceMaskRequest()
    
    func getSubject(from image: UIImage) async throws -> UIImage {
        let url = try saveImageToTempURL(image: image)
        let request = ImageRequestHandler(url)
        guard let result = try await request.perform(GenerateForegroundInstanceMaskRequest()) else {
            throw ImageLifterError.noResults
        }
       
        
        let cvBuffer = try result.generateMaskedImage(
            for: result.allInstances,
            imageFrom: request,
            croppedToInstancesExtent: false
        )
        
        let ciImage = CIImage(cvImageBuffer: cvBuffer)
        let context = CIContext()
        
        guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageLifterError.cgImageCreationFailed
        }
        
        return UIImage(cgImage: outputCGImage)
    }
}


enum ImageLifterError: Error {
    case invalidImage
    case noResults
    case imageGenerationFailed
    case cgImageCreationFailed
}


