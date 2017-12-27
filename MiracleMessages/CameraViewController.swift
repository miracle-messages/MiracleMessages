//
//  CameraViewController.swift
//  MiracleMessages
//
//  Created by Win Raguini on 10/1/16.
//  Copyright © 2016 Win Inc. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import AWSS3
import MessageUI
import Photos
import SCLAlertView
import Alamofire
import MobileCoreServices
import Photos

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate, MFMailComposeViewControllerDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var recordBtnCntrVrtConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordBtnRtConstraint: NSLayoutConstraint!
    @IBOutlet weak var thankYouView: UIView!
    @IBOutlet weak var recordBtnBtmConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordBtnCenterConstraint: NSLayoutConstraint!
    @IBOutlet weak var percentageLbl: UILabel!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressBarView: UIProgressView!
    @IBOutlet weak var closeBtn: UIButton!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var questionScrollView: UIScrollView!
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var btnGallery: UIButton!
    //Thank you
    @IBOutlet weak var thnkYouMsgLabel: UILabel!
    @IBOutlet weak var infoMsgLabel: UILabel!
    @IBOutlet weak var doneBtn: UIButton!
    
    var images = [PHAsset]()
    var startTime = TimeInterval()
    var timer = Timer()
    var videoFileName: String?
    var video: Video?
    var videoURL: URL?
    var localVideoURL: URL?
    //Player
    var player: AVPlayer = AVPlayer()
    var avPlayerLayer: AVPlayerLayer!
    weak var delegate:CameraViewControllerDelegate?
    let currentCase: Case = Case.current
    var videoPickerController = UIImagePickerController()
    var cameraSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var isRecording = false
    let dataOutput = AVCaptureMovieFileOutput()
    let questionsArray: [String] = [
        "Hold your phone horizontally, hit record, and reconfirm permission on camera. 'Do we have your permission to record and share this video?' Once they say 'Yes', invite them to look at the camera, and speak to their loved one as if they were there."
    ]
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.progressBarView.progress = 0
        self.hideProgressView()

        //Set up capture session
        cameraSession = AVCaptureSession()
        cameraSession!.sessionPreset = AVCaptureSessionPreset1280x720

        //Add inputs
        configureCamera()
        configurePreview()

        self.questionScrollView.frame = CGRect(x: 0, y: self.previewView.frame.size.height, width: self.view.frame.size.width, height: 125)
        let scrollViewHeight: CGFloat = self.questionScrollView.frame.height
        let scrollViewWidth: CGFloat = self.questionScrollView.frame.width

        let scrollViewBgView = UIView(frame: CGRect(x: 0, y: 0, width: self.questionScrollView.frame.width, height: self.questionScrollView.frame.height))
        scrollViewBgView.backgroundColor = UIColor.black
        scrollViewBgView.alpha = 0.4

        self.questionScrollView.addSubview(scrollViewBgView)

        var questionWidth: CGFloat = 0
        for question in questionsArray {
            let questionLbl1 = UILabel(frame: CGRect(x: questionWidth, y: 0, width: scrollViewWidth, height: scrollViewHeight - 8))
            questionLbl1.textAlignment = NSTextAlignment.center
            questionLbl1.numberOfLines = 0
            questionLbl1.font = UIFont.init(name: "System", size: 15)
            questionLbl1.textColor = UIColor.white
            questionLbl1.text = question
            questionLbl1.alpha = 1
            self.questionScrollView.addSubview(questionLbl1)
            questionWidth += scrollViewWidth
        }

        self.pageControl.backgroundColor = UIColor.clear

        self.questionScrollView.contentSize = CGSize(width: scrollViewWidth * CGFloat(questionsArray.count), height: scrollViewHeight)
        self.questionScrollView.delegate = self
        self.pageControl.currentPage = 0

        pageControl.alpha = 1
        self.getLastVideoFromGallery()
    }
    
    func getLastVideoFromGallery() {
        let assets = PHAsset.fetchAssets(with: PHAssetMediaType.video, options: nil)
        if(assets.count > 0){
            self.images.append(assets.lastObject!)
        
        let options: PHVideoRequestOptions = PHVideoRequestOptions()
        options.version = .original
        PHImageManager.default().requestAVAsset(forVideo: self.images.last!, options: options, resultHandler: { (asset, audioMix, info) in
                if let urlAsset = asset as? AVURLAsset {
                    self.localVideoURL = urlAsset.url
                }
            })
        }
    }
    
    @IBAction func btnPickVideoFromGalletyClicked(_ sender: UIButton) {
        self.pickVideoFromGallery()
    }
    
    func pickVideoFromGallery(){
        videoPickerController.sourceType = .savedPhotosAlbum
        videoPickerController.delegate = self
        videoPickerController.mediaTypes = [(kUTTypeMovie as NSString) as String]
        self.present(videoPickerController, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        videoURL = info[UIImagePickerControllerMediaURL] as! NSURL as URL
        self.currentCase.localVideoURL = videoURL
       
        // get the asset
        let asset = AVURLAsset(url: videoURL!)
        let seconds = asset.duration.seconds
       
        self.dismiss(animated: true, completion: nil)
        
        if(seconds >= 180){
            let alert = UIAlertController(title: AppName, message: "Sorry! you can't upload more than 3 minutes video.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { action in
            }))
            alert.addAction(UIAlertAction(title: "Try again", style: UIAlertActionStyle.default, handler: { action in
                self.pickVideoFromGallery()
            }))
            self.present(alert, animated: true, completion: nil)
        } else{
            self.presentConfirmation(outputFileURL: videoURL)
        }
    }

    func configurePreview() {
        previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
        previewView.layer.addSublayer(previewLayer!)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.previewView.bringSubview(toFront: self.recordBtn)
        self.previewView.bringSubview(toFront: self.timerLabel)
        self.previewView.bringSubview(toFront: self.closeBtn)
    }

    func reconfigureQuestionScrollView() -> Void {
        var questionWidth: CGFloat = 0
        var currentFrame = CGRect.zero
        var page: Int = 0
        for questionView in self.questionScrollView.subviews {
            if let questionLbl = questionView as? UILabel {
                questionLbl.frame = CGRect(x: questionWidth, y: 0, width: self.questionScrollView.frame.width, height: self.questionScrollView.frame.height)
                questionWidth += self.questionScrollView.frame.width
                if self.pageControl.currentPage == page {
                    currentFrame = questionLbl.frame
                }
                page += 1
            } else {
                let backgroundViewFrame = questionView.frame
                let newWidth = self.questionScrollView.frame.width * CGFloat(self.questionsArray.count)
                questionView.frame = CGRect(x: -200, y: 0, width: newWidth + 500, height: backgroundViewFrame.height)
            }
        }
        self.questionScrollView.contentSize = CGSize(width: self.questionScrollView.frame.width * CGFloat(self.questionsArray.count), height: self.questionScrollView.frame.height)
        self.questionScrollView.scrollRectToVisible(currentFrame, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enableLandscapeConstraints()
        previewLayer!.frame = self.previewView.bounds

        reconfigureQuestionScrollView()

        let orientation = UIApplication.shared.statusBarOrientation
        let captureConnection = dataOutput.connection(withMediaType: AVMediaTypeVideo)
        switch orientation {
        case .portrait:
            previewLayer?.connection.videoOrientation = .portrait
            captureConnection?.videoOrientation = AVCaptureVideoOrientation.portrait
            enablePortraitConstraints()
            break
        case .landscapeRight:
            previewLayer?.connection.videoOrientation = .landscapeRight
            captureConnection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
            enableLandscapeConstraints()
            break
        case .landscapeLeft:
            previewLayer?.connection.videoOrientation = .landscapeLeft
            captureConnection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
            enableLandscapeConstraints()
            break
        case .portraitUpsideDown:
            previewLayer?.connection.videoOrientation = .portrait
            captureConnection?.videoOrientation = AVCaptureVideoOrientation.portrait
            enablePortraitConstraints()
            break
        default: break
        }
    }

    @IBAction func didPushNextBtn(_ sender: UIButton) {
        thnkYouMsgLabel.text = "What's next"
        infoMsgLabel.text = "Get in touch with your local chapter to begin searching for loved ones."
        doneBtn.setTitle("Home", for: .normal)
        doneBtn.removeTarget(nil, action: nil, for: UIControlEvents.allEvents)
        doneBtn.addTarget(self, action: #selector(CameraViewController.homeBtnSelected), for: .touchUpInside)
    }

    func homeBtnSelected()  {
        dimissCamera()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if (self.isMovingFromParentViewController) {
            UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.navigationController?.navigationBar.backgroundColor = UIColor.white
        self.navigationController?.navigationBar.tintColor = UIColor(red: 33.0/255.0, green: 33.0/255.0, blue: 33.0/255.0, alpha: 1.0)
    }

    func enablePortraitConstraints() -> Void {
        //Landscape constraints
        self.recordBtnCntrVrtConstraint.isActive = false
        self.recordBtnRtConstraint.isActive = false

        //Portrait constraints
        self.recordBtnBtmConstraint.isActive = true
        self.recordBtnCenterConstraint.isActive = true
    }

    func enableLandscapeConstraints() -> Void {
        //Landscape constraints
        self.recordBtnCntrVrtConstraint.isActive = true
        self.recordBtnRtConstraint.isActive = true

        //Portrait constraints
        self.recordBtnBtmConstraint.isActive = false
        self.recordBtnCenterConstraint.isActive = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.backgroundColor = UIColor.clear
        self.navigationController?.navigationBar.tintColor = UIColor.white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        cameraSession?.startRunning()
        
        if(self.localVideoURL != nil){
            let asset = AVURLAsset(url: self.localVideoURL!)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let timestamp = CMTime(seconds: 1, preferredTimescale: 60)

            do {
                let imageRef = try generator.copyCGImage(at: timestamp, actualTime: nil)
                self.btnGallery.setImage(UIImage(cgImage: imageRef), for: UIControlState.normal)
            }
            catch let error as NSError
            {
                print("Image generation failed with error \(error)")
                return
            }
        }
    }
    
    func optionAlertviewForPickingMedia() {
        let alert = UIAlertController(title: AppName, message: "Are you sure you want to record video or you can import video from camera roll also.", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { action in
        }))
        alert.addAction(UIAlertAction(title: "Photo Library", style: UIAlertActionStyle.default, handler: { action in
            self.pickVideoFromGallery()
        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    func showAlertView() {
        let alert = UIAlertController(title: "Are you sure you want to skip this step?", message: "Skip this step if the client would prefer not to record a video, or if you're a service provide and are unable to record the video.", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Don't Skip", style: UIAlertActionStyle.default, handler: { action in
        }))
        
        alert.addAction(UIAlertAction(title: "Skip", style: UIAlertActionStyle.default, handler: { action in
          if self.isRecording {
             self.stopTimer()
             self.changeRecordBtn(recording: false)
             self.dataOutput.stopRecording()
             self.isRecording = false
             }
            
            let confirmationController: ConfirmViewController = self.storyboard!.instantiateViewController(withIdentifier: IdentifireConfirmView) as! ConfirmViewController
            self.navigationController?.pushViewController(confirmationController, animated: true)

        }))
        
        self.present(alert, animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func configureCamera() -> Void {
        do {
            Logger.log("configureCamera")
            cameraSession?.beginConfiguration()

            let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            let captureDeviceAudio = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)


            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            let audioInput = try AVCaptureDeviceInput(device: captureDeviceAudio)

            if (cameraSession?.canAddInput(deviceInput) == true) {
                cameraSession?.addInput(deviceInput)
            }

            if (cameraSession?.canAddInput(audioInput) == true) {
                cameraSession?.addInput(audioInput)
            }

            if (cameraSession?.canAddOutput(dataOutput) == true) {
                cameraSession?.addOutput(dataOutput)
            }

            cameraSession?.commitConfiguration()

        }
        catch let error as NSError {
            Logger.forceLog(error)
        }
    }

    func updateTime() {
        let currentTime = NSDate.timeIntervalSinceReferenceDate
        var elapsedTime: TimeInterval = currentTime - startTime
        let minutes = UInt8(elapsedTime / 60.0)
        elapsedTime -= (TimeInterval(minutes) * 60)
        let seconds = UInt8(elapsedTime)
        elapsedTime -= TimeInterval(seconds)
        let fraction = UInt8(elapsedTime * 100)
        let strMinutes = String(format: "%02d", minutes)
        let strSeconds = String(format: "%02d", seconds)
        timerLabel.text = "\(strMinutes):\(strSeconds)/3:00"
        
        if(minutes >= 3){
            stopTimer()
            changeRecordBtn(recording: false)
            dataOutput.stopRecording()
            isRecording = false
        }
    }

    func showProgressView() {
        self.view.bringSubview(toFront: self.progressView)
    }

    func hideProgressView() {
        self.percentageLbl.text = "0%"
        self.view.sendSubview(toBack: self.progressView)
    }

    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        Logger.log("capture: outputFileUrl:\(outputFileURL)")
        if let error = error {
            Logger.forceLog(CustomError.caputureImageError(error.localizedDescription))
        }

        guard let _ = NSData(contentsOf: outputFileURL as URL) else {
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { saved, error in
            if let error = error {
                Logger.forceLog(CustomError.caputureImageError(error.localizedDescription))
            }
            
            if saved {
                Logger.log("Saved successfully.")
            }
        }

        cameraSession?.stopRunning()
        self.currentCase.localVideoURL = outputFileURL
        self.presentConfirmation(outputFileURL: outputFileURL)
    }

    @IBAction func didPressTakePhoto(_ sender: AnyObject) {
        if isRecording {
            stopTimer()
            changeRecordBtn(recording: false)
            dataOutput.stopRecording()
            isRecording = false
        } else {
            startTimer()
            changeRecordBtn(recording: true)
            let recordingDelegate:AVCaptureFileOutputRecordingDelegate? = self
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = documentsURL.appendingPathComponent("temp.mov")
            dataOutput.startRecording(toOutputFileURL: filePath, recordingDelegate: recordingDelegate)
        }
    }

    func changeRecordBtn(recording: Bool) -> Void {
        if recording {
            recordBtn.setBackgroundImage(UIImage(named:"stopRecordBtn"), for: .normal)
        } else {
            recordBtn.setBackgroundImage(UIImage(named:"recordBtn"), for: .normal)
        }
    }

    func startTimer() {
        if !timer.isValid {
            timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(CameraViewController.updateTime), userInfo: nil, repeats: true)
            startTime = NSDate.timeIntervalSinceReferenceDate
        }
    }

    func stopTimer() {
        timer.invalidate()
        timerLabel.text = "00:00"
    }

    func sendEmail() {
        let mailComposeViewController = configuredMailComposeViewController()
        if MFMailComposeViewController.canSendMail() {
            self.present(mailComposeViewController, animated: true, completion: nil)
        } else {
            self.showSendMailErrorAlert()
        }
    }

    func showSendMailErrorAlert() {
        let alertController = UIAlertController(title: "Error sending email.", message: "Could not send email.", preferredStyle: .alert)

        let OKAction = UIAlertAction(title: "OK", style: .default) { (action) in
        }
        alertController.addAction(OKAction)

        self.present(alertController, animated: true, completion: nil)
    }

    func displayVolunteerInfo() -> String {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "name"), let email = defaults.string(forKey: "email"), let phone = defaults.string(forKey: "phone"), let location = defaults.string(forKey: "location") {
            return "Volunteer information:\n\n\(name)\n\(email)\n\(phone)\n\(location)"
        } else {
            return "There was an issue."
        }
    }

    func videoLink() -> String {
        return "\(awsHost)/\(bucketName)/\(self.videoFileName!)"
    }

    func configuredMailComposeViewController() -> MFMailComposeViewController {
        let mailComposerVC = MFMailComposeViewController()
        mailComposerVC.mailComposeDelegate = self // Extremely important to set the --mailComposeDelegate-- property, NOT the --delegate-- property

        var components = DateComponents()
        components.setValue(1, for: .hour)

        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = .medium

        mailComposerVC.setToRecipients(["mm@miraclemessages.org"])
        mailComposerVC.setSubject("[MM] Interview video")
        mailComposerVC.setMessageBody("\(self.displayVolunteerInfo())\n\nLink to video:\n\(self.videoLink()).\n\nPlease add any additional notes here:", isHTML: false)

        return mailComposerVC
    }

    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        isRecording = true
        return
    }

    func compressVideo(inputURL: URL, outputURL: URL, handler:@escaping (_ exportSession: AVAssetExportSession?)-> Void) {
        let urlAsset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetMediumQuality) else {
            handler(nil)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileTypeQuickTimeMovie
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously { () -> Void in
            handler(exportSession)
        }
    }

    func generateVideoFileName() -> String {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: "name")?.replacingOccurrences(of: " ", with: "-").lowercased()
        let date = Date()
  
        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "MM-dd-yyyy-HHmmss"
        let stringDate = dayTimePeriodFormatter.string(from: date)
        if(name != nil){
            return "\(name!)-\(stringDate).mov"
        }else {
            return "\(stringDate).mov"
        }
    }

    func uploadtoS3(url: URL) -> Void {
        Logger.log("uploadtoS3: \(url.absoluteString)")
        let transferManager = AWSS3TransferManager.default()
        let uploadRequest1 : AWSS3TransferManagerUploadRequest = AWSS3TransferManagerUploadRequest()

        if let newVideoFileName = self.videoFileName {
            uploadRequest1.bucket = bucketName
            uploadRequest1.key =  newVideoFileName
            uploadRequest1.acl = AWSS3ObjectCannedACL.publicRead
            uploadRequest1.body = url

            uploadRequest1.uploadProgress = {(bytesSent:Int64,
                totalBytesSent:Int64, totalBytesExpectedToSend:Int64) in

                DispatchQueue.main.sync(execute: {[unowned self] () -> Void in
                    let percentage: Float = Float(totalBytesSent)/Float(totalBytesExpectedToSend)
                    self.progressBarView.progress = percentage

                    let percentFormatter = NumberFormatter()
                    percentFormatter.numberStyle = .percent

                    let percentageNumber = NSNumber(value: percentage)

                    self.percentageLbl.text = percentFormatter.string(from:  percentageNumber)
                    Logger.log("\(totalBytesSent) and total:\(totalBytesExpectedToSend) => \(percentage * 100)")
                })
            }

            let task = transferManager.upload(uploadRequest1)
            task.continueWith(block: { (task) -> AnyObject! in
                if let error = task.error {
                    Logger.log(level: Level.error, "Failure uploadtoS3!")
                    Logger.forceLog(CustomError.videoUploadError(error.localizedDescription))
                } else {
                    Logger.log("Upload successful")
                    DispatchQueue.main.async(execute: {[unowned self] in
                        //self.sendInfo()
                        self.hideProgressView()
                    })
                }
                return nil
            })
        }
    }

    func dimissCamera() -> Void {
        self.delegate?.didFinishRecording(sender: self)
        let _ = navigationController?.popViewController(animated: true)
    }

    func presentConfirmation(outputFileURL: URL!) -> Void {
        let confirmationController: ConfirmViewController = storyboard!.instantiateViewController(withIdentifier: IdentifireConfirmView) as! ConfirmViewController
        
        confirmationController.video = Video(contentType: "application/octet-stream", completionBlock: nil, awsHost: awsHost, bucketName: bucketName, name: self.generateVideoFileName(), url: outputFileURL)

        let backItem = UIBarButtonItem()
        backItem.title = "Retake Video?"
        navigationItem.backBarButtonItem = backItem
        confirmationController.navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(confirmationController, animated: true)
    }

    @IBAction func didPressCloseBtn(_ sender: AnyObject) {
        self.showAlertView()
    }
}

extension CameraViewController : UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth:CGFloat = scrollView.frame.width
        let currentPage:CGFloat = floor((scrollView.contentOffset.x-pageWidth/2)/pageWidth)+1
        self.pageControl.currentPage = Int(currentPage);
    }
}
