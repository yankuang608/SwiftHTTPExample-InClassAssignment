//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//

// This exampe is meant to be run with the python example:
//              tornado_example.py 
//              from the course GitHub repository: tornado_bare, branch sklearn_example


// if you do not know your local sharing server name try:
//    ifconfig |grep inet   
// to see what your public facing IP address is, the ip address can be used here
//let SERVER_URL = "http://erics-macbook-pro.local:8000" // change this for your server name!!!
let SERVER_URL = "http://10.8.150.172:8000" // change this for your server name!!!

import UIKit
import CoreMotion

class ViewController: UIViewController, URLSessionDelegate {
    
    // MARK: Class Properties
    var session = URLSession()
    let operationQueue = OperationQueue()
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    var ringBuffer = RingBuffer()
    let animation = CATransition()
    let motion = CMMotionManager()
    
    var magValue = 0.06
    var isCalibrating = false
    
    var isWaitingForMotionData = false
    
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var upArrow: UILabel!
    @IBOutlet weak var rightArrow: UILabel!
    @IBOutlet weak var downArrow: UILabel!
    @IBOutlet weak var leftArrow: UILabel!
    @IBOutlet weak var largeMotionMagnitude: UIProgressView!
    
    @IBOutlet weak var predictLabel: UILabel!
    
    // MARK: Class Properties with Observers
    enum CalibrationStage {
        case notCalibrating
        case tapUp
        case tapRight
        case tapDown
        case tapLeft
        case patUp
        case patRight
        case patDown
        case patLeft
    }
    
    var calibrationStage:CalibrationStage = .notCalibrating {
        didSet{
            switch calibrationStage {
            case .tapUp:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsCalibrating(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
            case .tapLeft:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsCalibrating(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
            case .tapDown:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsCalibrating(self.downArrow)
                }
                break
                
            case .tapRight:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsCalibrating(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
            case .patUp:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsCalibrating(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
            case .patLeft:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsCalibrating(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
            case .patDown:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsCalibrating(self.downArrow)
                }
                break
                
            case .patRight:
                self.isCalibrating = true
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsCalibrating(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
                
            case .notCalibrating:
                self.isCalibrating = false
                DispatchQueue.main.async{
                    self.setAsNormal(self.upArrow)
                    self.setAsNormal(self.rightArrow)
                    self.setAsNormal(self.leftArrow)
                    self.setAsNormal(self.downArrow)
                }
                break
            }
        }
    }
    
    var dsid:Int = 0 {
        didSet{
            DispatchQueue.main.async{
                // update label when set
                self.dsidLabel.layer.add(self.animation, forKey: nil)
                self.dsidLabel.text = "Current DSID: \(self.dsid)"
            }
        }
    }
    
    @IBAction func magnitudeChanged(_ sender: UISlider) {
//        self.magValue = Double(sender.value)
//        print(self.magValue)
    }
    
    // MARK: Core Motion Updates
    func startMotionUpdates(){
        // some internal inconsistency here: we need to ask the device manager for device
        
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 0.005
            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleAcceleration )
        }
    }
    
    func handleAcceleration(_ motionData:CMDeviceMotion?, error:Error?){
        if let accel = motionData?.userAcceleration {
            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
            
            DispatchQueue.main.async{
                //show magnitude via indicator
                self.largeMotionMagnitude.progress = Float(mag)/0.2
            }
            
            if mag > self.magValue {
                // buffer up a bit more data and then notify of occurrence
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                    self.calibrationOperationQueue.addOperation {
                        // something large enough happened to warrant
                        self.largeMotionEventOccurred()
                    }
                })
            }
        }
    }
    
    
    //MARK: Calibration procedure
    func largeMotionEventOccurred(){
        if(self.isCalibrating){
            //send a labeled example
            if(self.calibrationStage != .notCalibrating && self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                
                // send data to the server with label
                sendFeatures(self.ringBuffer.getDataAsVector(),
                             withLabel: self.calibrationStage)
                
                self.nextCalibrationStage()
            }
        }
//        else
//        {
//            if(self.isWaitingForMotionData)
//            {
//                self.isWaitingForMotionData = false
//                //predict a label
//                getPrediction(self.ringBuffer.getDataAsVector())
//                // dont predict again for a bit
//                setDelayedWaitingToTrue(2.0)
//
//            }
//        }
    }
    
    func nextCalibrationStage(){
        switch self.calibrationStage {
        //tap Round
        case .notCalibrating:
            //start with up arrow
            self.calibrationStage = .tapUp
            setDelayedWaitingToTrue(1.0)
            break
        case .tapUp:
            self.calibrationStage = .tapRight
            setDelayedWaitingToTrue(1.0)
            break
        case .tapRight:
            self.calibrationStage = .tapDown
            setDelayedWaitingToTrue(1.0)
            break
        case .tapDown:
            self.calibrationStage = .tapLeft
            setDelayedWaitingToTrue(1.0)
            break
        case .tapLeft:
            self.calibrationStage = .patUp
            setDelayedWaitingToTrue(1.0)
            
        // pat Round
        case .patUp:
            //start with up arrow
            self.calibrationStage = .patRight
            setDelayedWaitingToTrue(1.0)
            break
        case .patRight:
            //go to right arrow
            self.calibrationStage = .patDown
            setDelayedWaitingToTrue(1.0)
            break
        case .patDown:
            //go to down arrow
            self.calibrationStage = .patLeft
            setDelayedWaitingToTrue(1.0)
            break
        case .patLeft:
            //go to left arrow
            self.calibrationStage = .notCalibrating
            setDelayedWaitingToTrue(1.0)
            break
        }
    }
    
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
    
    func setAsCalibrating(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.red
    }
    
    func setAsNormal(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.white
    }
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        self.session = URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
        
        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        animation.type = kCATransitionFade
        animation.duration = 0.5
        
        
        // setup core motion handlers
        startMotionUpdates()
        
        dsid = 40 // set this and it will update UI
    }

    //MARK: Get New Dataset ID
    @IBAction func getDataSetId(_ sender: AnyObject) {
        // create a GET request for a new DSID from server
        let baseURL = "\(SERVER_URL)/GetNewDatasetId"
        
        let getUrl = URL(string: baseURL)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    print("Response:\n%@",response!)
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    // This better be an integer
                    if let dsid = jsonDictionary["dsid"]{
                        self.dsid = dsid as! Int
                    }
                }
                
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: Calibration
    @IBAction func startCalibration(_ sender: AnyObject) {
        self.isWaitingForMotionData = false // dont do anything yet
        nextCalibrationStage()
        
    }
    
    //MARK: Comm with Server
    func sendFeatures(_ array:[Double], withLabel label:CalibrationStage){
        let baseURL = "\(SERVER_URL)/AddDataPoint"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array,
                                       "label":"\(label)",
                                       "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
            completionHandler:{(data, response, error) in
                if(error != nil){
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    print(jsonDictionary["feature"]!)
                    print(jsonDictionary["label"]!)
                }

        })
        
        postTask.resume() // start the task
    }
    
    func getPrediction(_ array:[Double]){
        let baseURL = "\(SERVER_URL)/PredictOne"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // data to send in body of post request (send arguments as json)
        let jsonUpload:NSDictionary = ["feature":array, "dsid":self.dsid]
        
        
        let requestBody:Data? = self.convertDictionaryToData(with:jsonUpload)
        
        request.httpMethod = "POST"
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                                                                  completionHandler:{(data, response, error) in
                                                                    if(error != nil){
                                                                        if let res = response{
                                                                            print("Response:\n",res)
                                                                        }
                                                                    }
                                                                    else{
                                                                        let jsonDictionary = self.convertDataToDictionary(with: data)
                                                                        
                                                                        let labelResponse = jsonDictionary["prediction"]!
                                                                        print(labelResponse)
//                                                                        self.displayLabelResponse(labelResponse as! String)

                                                                    }
                                                                    
        })
        
        postTask.resume() // start the task
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "['up']":
            blinkLabel(upArrow)
            break
        case "['down']":
            blinkLabel(downArrow)
            break
        case "['left']":
            blinkLabel(leftArrow)
            break
        case "['right']":
            blinkLabel(rightArrow)
            break
        default:
            print("Unknown")
            break
        }
    }
    
    func blinkLabel(_ label:UILabel){
        DispatchQueue.main.async {
            self.setAsCalibrating(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.setAsNormal(label)
            })
        }
        
    }
    
    @IBAction func makeModel(_ sender: AnyObject) {
        
        // create a GET request for server to update the ML model with current data
        let baseURL = "\(SERVER_URL)/UpdateModel"
        let query = "?dsid=\(self.dsid)"
        
        let getUrl = URL(string: baseURL+query)
        let request: URLRequest = URLRequest(url: getUrl!)
        let dataTask : URLSessionDataTask = self.session.dataTask(with: request,
              completionHandler:{(data, response, error) in
                // handle error!
                if (error != nil) {
                    if let res = response{
                        print("Response:\n",res)
                    }
                }
                else{
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    
                    if let SVMAcc = jsonDictionary["SVM"]{
                        print("SVM Accuracy is", SVMAcc)
                    }
                    
                    if let RFAcc = jsonDictionary["RandomForest"]{
                        print("Random Forest Accuracy is", RFAcc)
                    }
                    
                    if let KNNAcc = jsonDictionary["N_Neighbors"]{
                        print("KNN Accuracy is", KNNAcc)
                    }
                }
                                                                    
        })
        
        dataTask.resume() // start the task
        
    }
    
    //MARK: JSON Conversion Functions
    func convertDictionaryToData(with jsonUpload:NSDictionary) -> Data?{
        do { // try to make JSON and deal with errors using do/catch block
            let requestBody = try JSONSerialization.data(withJSONObject: jsonUpload, options:JSONSerialization.WritingOptions.prettyPrinted)
            return requestBody
        } catch {
            print("json error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertDataToDictionary(with data:Data?)->NSDictionary{
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: NSDictionary =
                try JSONSerialization.jsonObject(with: data!,
                                              options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
            
            return jsonDictionary
            
        } catch {
            print("json error: \(error.localizedDescription)")
            return NSDictionary() // just return empty
        }
    }

}





