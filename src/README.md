11/16下午 楊
1.分好module檔案
2.粗略完成I2cInitializer

分工：
楊：
I2C
I2cInitializer
翁：
AudRecorder

謝：
AudDSP
AudPlayer


11/17 晚 mao7
1. 試著寫了一個recorder的testbench
2. 初步debug完了，recorder正常run是ok的(沒有stop/pause)
3. 用法 : i_start跟第一個bit同時進來。 (I2S的第一個bit是MSB)
4. 如果要生testbench可以看我的模板
Some notes：
1.
DSP 負責根據播放速度 UP / DOWN sampling

2.
player 負責把 output 變成 I2S 形式送給 WM8731

3.
recorder 負責把 input 變成 I2S 形式存到 SRAM

4.
I2cInitializer 負責以 I2C 初始化 WM8731


