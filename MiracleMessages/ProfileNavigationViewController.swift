//
//  ProfileNavigationViewController.swift
//  MiracleMessages
//
//  Created by Win Raguini on 1/10/17.
//  Copyright © 2017 Win Inc. All rights reserved.
//

import UIKit

class ProfileNavigationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backBtn = UIButton(type: UIButtonType.custom)
        backBtn.setImage(UIImage.init(named: "backBtn"), for: .normal)

        self.navigationController?.navigationBar.transparentNavigationBar()

        let profileBtn = UIButton(type: UIButtonType.custom)
        profileBtn.setImage(UIImage.init(named: "homeBtn"), for: .normal)
        profileBtn.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        profileBtn.addTarget(self, action: #selector(didPressProfileBtn), for: UIControlEvents.touchUpInside)
        let profileBarBtnItem = UIBarButtonItem(customView: profileBtn)
        self.navigationItem.rightBarButtonItem = profileBarBtnItem
    }

    func didPressProfileBtn() -> Void {
        let menuController = storyboard!.instantiateViewController(withIdentifier: IdentifireMenuView)
        navigationController?.pushViewController(menuController, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
    }
}
