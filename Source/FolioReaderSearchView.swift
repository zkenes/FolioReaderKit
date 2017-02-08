//
//  FolioReaderSearchView.swift
//  FolioReaderKit
//
//  Created by Zhanserik on 1/31/17.
//  Copyright © 2017 FolioReader. All rights reserved.
//

import UIKit

class FolioReaderSearchView: UIViewController, UITableViewDataSource, UITableViewDelegate,UISearchBarDelegate {
    
    private var search: UISearchBar?
    private var table: UITableView?
    private var barHeight: CGFloat?
    private var displayWidth: CGFloat?
    private var displayHeight: CGFloat?
    private let SEARCHBAR_HEIGHT: CGFloat = 44
    private var matches:[NSTextCheckingResult]?    //:[String]?  // = [""]  //:[String]?
    private var matchesStrArray:[String] = []
    private var adjustedMatches:[NSTextCheckingResult] = []
    private var bodyHtml:String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        self.bodyHtml = FolioReader.shared.readerCenter?.currentPage?.getHTML()
        
        barHeight = UIApplication.shared.statusBarFrame.size.height  //0
        displayWidth = self.view.frame.width
        displayHeight = self.view.frame.height
        
        self.search = UISearchBar();
        self.search!.delegate = self
        self.search!.frame = CGRect(x: 0, y: 0, width: displayWidth!, height: SEARCHBAR_HEIGHT)
        self.search!.layer.position = CGPoint(x: self.view.bounds.width/2, y: 80)
        self.search!.showsCancelButton = false
        self.search!.placeholder = "Search"
        self.view.addSubview(search!)
    
        setCloseButton()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar){   //protocolの実装
        
//        self.search?.isUserInteractionEnabled = false
        
        let pattern = "([a-zA-Z0-9]|.){0,10}\(search!.text!)([a-zA-Z0-9]|.){0,10}"
        // "<highlight id=\" onclick=\".*?\" class=\"(.*?)\">((.|\\s)*?)</highlight>"
        self.matches =  RegExp(pattern).matches(input: self.bodyHtml!)
        print("matchesは\(self.matches)")
        
        if(self.matches != nil){
            let matchCount = self.matches!.count
            for i in 0 ..< matchCount {
                
                let matchHtmlStr = (self.bodyHtml! as NSString).substring(with: self.matches![i].range)
                let matchStr = self.stripTagsFromStr(htmlStr: matchHtmlStr)
                print("タグを抜いたmatchStrは\(matchStr)")
                if matchStr.contains("\(search!.text!)") {  //大文字、小文字を別々に評価
                    //tableに表示
                    print("firstは \(self.adjustedMatches.first)")
                    if(self.adjustedMatches.first == nil){
                        self.adjustedMatches.append(self.matches![i])  //insertはダメ
                    }else{
                        self.adjustedMatches.append(self.matches![i])
                    }
                    self.matchesStrArray.append( matchStr )
                }else{
                    //tableに表示させない
                }
            }
            
            if(self.matchesStrArray.count > 0){
                if(self.table == nil){
                    
                    self.addTable()
                }
            }else{
                self.showSearchAlert()
            }
            
            //機能追加:下にリロードしたら動的に列を追加したい(最初は10件まで表示?)
            /*self.table!.beginUpdates()
             self.matches = searchResult
             var indexPathArray:[NSIndexPath]=[]
             for row in 0..<self.matches!.count {
             let indexPath = NSIndexPath(forRow: row, inSection: 0)
             indexPathArray.append(indexPath)
             }
             self.table!.insertRowsAtIndexPaths(indexPathArray, withRowAnimation: .Top)
             self.table!.endUpdates()
             self.table!.reloadData()*/
            
        }else{
            self.showSearchAlert()
        }
    }
    func showSearchAlert(){
        let searchAlert = UIAlertView()
        searchAlert.delegate = self
        searchAlert.title = ""
        searchAlert.message = "Nothin was found"
        searchAlert.addButton(withTitle: "Ok")
        searchAlert.show()
    }

    
    func addTable(){
        
        self.table = UITableView();
        self.table!.frame = CGRect(x: 0, y: barHeight! + SEARCHBAR_HEIGHT + 60, width: displayWidth!, height: displayHeight! - barHeight! - SEARCHBAR_HEIGHT - 60);
        self.table!.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.table!.delegate = self
        self.table!.dataSource = self;
        self.view.addSubview(table!)
    }
    
    func tableView(_ table: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.adjustedMatches.count
    }
    
    func tableView(_ table: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        print("indexPath == \(indexPath)")
        
        let cell = table.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "\(matchesStrArray[indexPath.row])"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let item = self.adjustedMatches[indexPath.row]
        let itemStr = (self.bodyHtml! as NSString).substring(with: item.range)
        let searchTextLocation = (itemStr as NSString).range(of: search!.text!).location
        //その位置の分だけずらす
        let adjustedRange = NSMakeRange(item.range.location + searchTextLocation, search!.text!.characters.count)
        
        self.dismiss(animated: true, completion: nil)
        
        //searchタグの挿入操作(全てJS側でやってもうまくいきそう)
        //検索文字列の部分だけにハイライトタグを追加する
        //let content = (self.bodyHtml! as NSString).substringWithRange(adjustedRange)
        let searchTagId = "search"
        var bodyHtmls = (self.bodyHtml! as NSString)
        let style = HighlightStyle.classForStyle(2)  //青色
        let tag = "<search id=\"\(searchTagId)\" class=\"\(style)\">\(search!.text!)</search>"
        
        //これを使うと同一文字があると個別に移動できない
        //let range: NSRange = adjustedRange   //bodyHtmls.rangeOfString(content, options: .LiteralSearch)
        if adjustedRange.location != NSNotFound {
            
            bodyHtmls = bodyHtmls.replacingCharacters(in: adjustedRange, with: tag) as (NSString)
            let currentPageNum = FolioReader.shared.readerCenter?.currentPage?.pageNumber
            let resource = book.spine.spineReferences[currentPageNum!-1].resource
            FolioReader.shared.readerCenter?.currentPage?.webView.tag = 1  //didfinishLoad時に行移動させるため
            FolioReader.shared.readerCenter?.currentPage?.webView.alpha = 0
            print("bodyHtmlsは\(bodyHtmls)")
            
            var html = FolioReader.shared.readerCenter?.currentPage?.getHTML()
            
            // <body>[.\n]<\/body>
            //  ((?:.(?!<body[^>]*>))+.<body[^>]*>)|(</body\>.+)
            // /<body[^>]*>((.|[\n\r])*)<\/body>/im
            // (?i)<body>\\s*</body>
            html = html?.replacingOccurrences(of: "<body>(.|[\n])*</body>", with: bodyHtmls as String, options: .regularExpression, range:  nil)
            
            guard let line = resource?.fullHref as? NSString else {return}
            let path = line.deletingLastPathComponent as String
            let url = URL(fileURLWithPath: path)
            FolioReader.shared.readerCenter?.currentPage?.webView.loadHTMLString(html! as String, baseURL: url)
        }
        else {
            print("item range not found")
        }
    }
    
    func stripTagsFromStr( htmlStr:String)-> String {
        var htmlStr = htmlStr
        htmlStr = htmlStr.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        htmlStr = htmlStr.replacingOccurrences(of: "<[^>]*", with: "", options: .regularExpression, range: nil)
        htmlStr = htmlStr.replacingOccurrences(of: "[^<]*>", with: "", options: .regularExpression, range: nil)
        return htmlStr.trimmingCharacters(in: CharacterSet.whitespaces)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
