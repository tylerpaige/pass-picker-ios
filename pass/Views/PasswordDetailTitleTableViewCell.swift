//
//  PasswordDetailTitleTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 6/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class PasswordDetailTitleTableViewCell: UITableViewCell {
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var passwordImageImageView: UIImageView!
    @IBOutlet var labelImageConstraint: NSLayoutConstraint!
    @IBOutlet var labelCellConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Let a multi-line path tree grow the cell instead of being clipped to the image height.
        let imageBottom = contentView.constraints.filter { $0.firstAttribute == .bottomMargin && $0.secondItem === passwordImageImageView }
        NSLayoutConstraint.deactivate(imageBottom)
        passwordImageImageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -4).isActive = true
        categoryLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -12).isActive = true
        // Pass Picker's entry title has no icon.
        passwordImageImageView.isHidden = true
        labelImageConstraint.isActive = false
        labelCellConstraint.isActive = true
    }
}
