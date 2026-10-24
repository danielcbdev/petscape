# V9 provenance — dance and cleanup (M16)

- Date: 2026-10-23. Method (owner-approved change from the hand-drawn brief): cut-out rig,
  `scripts/build-m15-rig.swift`, `RIG_CLIPS=dance,cleanup`, built from the single authored key
  `assets/characters/cat/walk/frames/walk_01.png` (read-only, unchanged). Parts move by rigid
  rotation/translation only; the eyelids and the cleanup tongue are painted overlays. No reference file
  was edited, re-exported or copied as a frame.
- Build: `swiftc -O scripts/build-m15-rig.swift -o <tmp>/rig && RIG_CLIPS=dance,cleanup <tmp>/rig . assets/characters/cat/v9`
  (the script refuses to overwrite existing files). `rig-report.json` records each drawing's
  duration and paw contacts.
- Integrated 2026-10-23 (T16.8) as the `dance` and `cleanup` clips of `../character.json`.

## SHA-256

```text
8cf383b389c6aa5cc01f0fbf395ed260b6eb7cd0749f6fc3343f4b7124787002  ./cleanup/frames/cleanup_01.png
2248005ccfecb162f7196a67c58df4d0c83009f35d21904c87a017b723e0d96c  ./cleanup/frames/cleanup_02.png
d6866ece3a7a2652e6ae525da9b911311791de5a67f116e56c8ea043d111219e  ./cleanup/frames/cleanup_03.png
5344e63377a1a0cedaa46ca4964b519e33d52f1244a9772856d3d360ebead742  ./cleanup/frames/cleanup_04.png
5ce217eb559a53c49f75b29a1860141049024e68b0fdd873654376a665f5d8bb  ./cleanup/frames/cleanup_05.png
004a6a21595e7fc91439645bee9281278b72ec7fa30e0d13195b4d19faf4cff6  ./cleanup/frames/cleanup_06.png
4c99eb0942ba97e5900c9c21e32f241504c92040506311acb6813e3f58bb7eea  ./cleanup/frames/cleanup_07.png
2690bdcde7f74c6c3d3f11bf88e450d8f1e70c0918afe2743f149dce4c983fd3  ./cleanup/frames/cleanup_08.png
1cdf0678c8bd7337f562d29452162403a3f015a593a0f22e77d991b54667f47f  ./cleanup/frames/cleanup_09.png
bed83eb1586e310698217b51aab3626caf61f0a6a7c55c09b0ef34a9e2285daf  ./cleanup/frames/cleanup_10.png
802c84d235306503c383a73b3247598fb6022f0a4d65e1db30aa5c7a3eb2ba4f  ./cleanup/frames/cleanup_11.png
fe73b44aa5ebc788cdbf1a277bcedf702685e0b203f8a9e1e8d8bf39ee557455  ./cleanup/frames/cleanup_12.png
557c97e60baa617dee2d1c6349a3d7b8cd167d0d461aee6e2d27380b4b003134  ./cleanup/frames/cleanup_13.png
2f197bb3cc4ad272c670f50e39a7077bde2307c70607b7c8e435b5d13c6de90c  ./cleanup/frames/cleanup_14.png
a4eb23db1b1d6c5d7b6f13be0899639ae33edba93fdf861d303848b300103cc9  ./cleanup/frames/cleanup_15.png
4e96d8c63d577b618da6f0dc1be63ab6ad798f5f4fa626ca5ceefbd8c6f4cee7  ./cleanup/frames/cleanup_16.png
e09d7a4f75a4f95a49ba91569ab927bce1770070c49336f41636537d5c321b6e  ./cleanup/frames/cleanup_17.png
01ee597a0e0fd5d737de1f1a2e4b8b100b552c400ff1f87629335326d8d333cb  ./cleanup/frames/cleanup_18.png
8c27993983fa4ef19d9bbf098293841731bc052b01692514a3fc784167855bd2  ./cleanup/frames/cleanup_19.png
e291c430dce25f9c12124bdd9bdfb3b5a6536289b1425d0716b0895d7b75a692  ./cleanup/frames/cleanup_20.png
b9d069666ddbe14276b4616b6c267365b49a5d7d1b8306e7fad2a392e6450374  ./cleanup/frames/cleanup_21.png
b0db66dad107389e3fdc0ff0d47ea03c22c5d2b5117ad698f81f7352961d0ea0  ./cleanup/frames/cleanup_22.png
c469067f1db66b199a3940ac73f2226e90e3e2b0d0e32a25a34a61999264e96e  ./cleanup/frames/cleanup_23.png
5ffd26b14299926a2592bba446a4c5210bb1c8c56b441291057973a165d60523  ./cleanup/frames/cleanup_24.png
04ee5de61397a531ce82deb132830eb7b694a6c67ddb2d25440284c56f804053  ./cleanup/frames/cleanup_25.png
a2c1e6bfa8a449d4ffa4055b4430d48eba3bd1c527fd7b985a02574d91c01633  ./cleanup/frames/cleanup_26.png
3e6e4df09f391617c5914782f48278a2823ad936bf3c7ec118b13394b26e423e  ./cleanup/frames/cleanup_27.png
16960e9d54c628dea319a11e124b8790dc9940a16a17b3281476c27851f23fb4  ./cleanup/frames/cleanup_28.png
15578d8840ea097a96e29a724e1af6ab5b1627734d4b13f3bae7710a1ce8a2fe  ./cleanup/frames/cleanup_29.png
ec0b28d38146abbeb3abb16515bd6618ebd790970318860ac3e972649940db9f  ./cleanup/frames/cleanup_30.png
17f8d04c6ea52b185e421de6bdae863a56d0603a2e23eba80e200a94e636cf15  ./cleanup/frames/cleanup_31.png
6faf0f685fac9824e4abc7fecd0e5051a59d754ce406106aed32bded18970016  ./cleanup/frames/cleanup_32.png
07407625800e24b53569ebb3dc0c6ba8b699c530a4d6ddcfb89c991985834bcc  ./cleanup/frames/cleanup_33.png
bd3e1364464be11bf2c417f03a44867268c53ac72107e26b1610f1910328dc31  ./cleanup/frames/cleanup_34.png
58fd001fa31bfc10964ee4e7c073f3dc5efe7552db0ccfee6b65aad12ec5a714  ./cleanup/frames/cleanup_35.png
3e56b2977a108224fdf7643a630131ac1efaadc7191fda612cf929ecec925faf  ./cleanup/frames/cleanup_36.png
1e958ac23c4553faea306dea29cb5039f6a74241b4af68ad91453679709b08b9  ./dance/frames/dance_01.png
4332061a3ebae27967dab92dee51d154967b74428550e16ed7a2e8327a28ddc9  ./dance/frames/dance_02.png
1603cc2d9ee1d5ffeac47f22524e39125504da4864b9ff5baa2064d1a1690cb1  ./dance/frames/dance_03.png
c7fbcb5584054c9deb9fd09b32db9b79f6a3e21f1f04424f10acbc1acb0e2017  ./dance/frames/dance_04.png
140b0389f5126beb52548517779370b7956bc1e93b716796bd900adaae94ba7a  ./dance/frames/dance_05.png
36409f70e1711db711d15a02df8bd36a839911c763e2267c540594c7a4f3607f  ./dance/frames/dance_06.png
a49a1ea50e752b285bd0b4b4369767a39688f6674f739b9971153e1e601e787a  ./dance/frames/dance_07.png
2a4d3de4b5b4c4b670cf101f13a0750a7cd182548a60a30420c7a54ac73e785b  ./dance/frames/dance_08.png
9273b90f5415eabb01be29c56e231eb68cf7c76d9576d8aab47c2e8264e79a24  ./dance/frames/dance_09.png
7313ca21ad1a401f8d9e1c47a4973aad461f4ba9843ac707be5dce9738406f41  ./dance/frames/dance_10.png
560ee71bfb6ef3b9c627acce5fbbd42546530fbbf645091b6f61cfe9e48ed3e2  ./dance/frames/dance_11.png
ce324ca974f6d385144ed459c44ed9f6c4d7a9ca3e3fdf29b002f8957b4cde11  ./dance/frames/dance_12.png
2a7e1c3ae4c5bb2de6483ca9368016e24a15e17ef7a683833e3718208ec08219  ./dance/frames/dance_13.png
11c11c290c05dabceb6ad6837fe4fbeda92928c9167bb6f13885d3c9fd64d49b  ./dance/frames/dance_14.png
58ab221a4e93c85f9c6cd77bb5f268128c419c8efbb17f50fcc21ecbadfb11a7  ./dance/frames/dance_15.png
1434204d9bb469e3c6ba3ce785fc9af668715a00a84994e8ee328dc31da41868  ./dance/frames/dance_16.png
c3958e04d8639bed4a384e67530040963c7f4d7eb213d94126666efd7ac252d7  ./dance/frames/dance_17.png
58b0dda4404f6e25f8049bdbc92c9a5c61357203ae3025a44e8799d468de6c36  ./dance/frames/dance_18.png
2b13e6454a4ecb8ddd15e10800285d02bd9853a0e3c6d85acc8ff8e0d64deefb  ./dance/frames/dance_19.png
72fc5fc9f6068a235061554aea102f71954d44c0f6e3fcabc91766050a293085  ./dance/frames/dance_20.png
c1c121e9cbfd9af585478ec2c840f552cb1f9c01ef030522bc0faf56542a2331  ./dance/frames/dance_21.png
dab2de6a5c95baf61d3abb625c2e59c818a8f33397cf0ac441591adc6a6ae90d  ./dance/frames/dance_22.png
ff3c01d4f528747294ffe9d5297191a18814a99f7c8d2f095741d1b85fbdecd6  ./dance/frames/dance_23.png
0b1a2a52f584873b9c63bfd6b2d4cb99e2c19e2e3ed09755ebd09251600c0838  ./dance/frames/dance_24.png
4930439e53031e701e34bf465a3910b6892cabff5a24e43bee1c51b83c998ef4  ./dance/frames/dance_25.png
987d785164488676cef37470fac13a558af8cafc1d678f39a7e155c9ed5c8cc0  ./dance/frames/dance_26.png
885e38c32fc657fc7e750a8c649772fa0864705887e92df661e6de107f3ccc0d  ./dance/frames/dance_27.png
12041cc56d7199ac052e4ad6dff8f5773a9758829c28cac0dcdc0367114dfb5d  ./dance/frames/dance_28.png
78c327fa0f3012c9f9a16560a58ee7b93c910f18e86dbb657a5a27174817ea64  ./dance/frames/dance_29.png
2aceb2476284634cf28b3e2d52747a0a0322d108da7c9d8813793bd98e6a2dc7  ./dance/frames/dance_30.png
```
