
# https://www.ieee802.org/3/10GEPON_study/public/july06/thaler_1_0706.pdf

class PCSTestVector:

    eg_xgmii_data = [
            (int("0b11111111", 2), int("0x0707070707070707", 16)),
            (int("0b00000001", 2), int("0xd5555555555555fb", 16)),
            (int("0b00000000", 2), int("0x8b0e380577200008", 16)),
            (int("0b00000000", 2), int("0x0045000800000000", 16)),
            (int("0b00000000", 2), int("0x061b0000661c2800", 16)),
            (int("0b00000000", 2), int("0x00004d590000d79e", 16)),
            (int("0b00000000", 2), int("0x0000eb4a2839d168", 16)),
            (int("0b00000000", 2), int("0x12500c7a00007730", 16)),
            (int("0b00000000", 2), int("0x000000008462d21e", 16)),
            (int("0b00000000", 2), int("0x79f7eb9300000000", 16)),
            (int("0b11111111", 2), int("0x07070707070707fd", 16)),
            (int("0b11111111", 2), int("0x0707070707070707", 16))
        ]

    eg_scrambled_data = [
        (int("0b01", 2), int("0x7bfff0800000001e", 16)),
        (int("0b01", 2), int("0x623016aaaaad1578", 16)),
        (int("0b10", 2), int("0x6a767c6ec581e108", 16)),
        (int("0b10", 2), int("0x8df4aacc802830e6", 16)),
        (int("0b10", 2), int("0x2cdb936dae49ee83", 16)),
        (int("0b10", 2), int("0x74905a82db7046f3", 16)),
        (int("0b10", 2), int("0xc57a251a6b79511e", 16)),
        (int("0b10", 2), int("0x4aca440cd4bf1f41", 16)),
        (int("0b10", 2), int("0x2c3f2db5d2122809", 16)),
        (int("0b10", 2), int("0x320e33b3c8de9249", 16)),
        (int("0b01", 2), int("0xb599add7c83aa32a", 16))
    ]


       
       
     
       
       
       
       
       
       