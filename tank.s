# 图形显示模式
# 低 12 位为像素点RRRR_GGGG_BBBB，高四位为待定属性,VGA 储存 640*480 点像素，按照从左到右、从上到下的顺序储存在 VRAM_GRAPH 中

# ######################################################
# 全局变量：
# $s7=0xFFFFD000 ps2地址
# $s6=0x000C2000 vga地址
# $sp=0x0000FFFF 堆栈指针地址
# $t0=当前点地址
# $s0=当前点的颜色
# ######################################################

ori $sp, $zero, 0xFFFF      # 先给$sp一个地址，避免溢出

# li $s7, 0xFFFFD000
lui $s7, 0xFFFF             # $s7 = 0xFFFFD000 ps2地址
ori $s7, $s7, 0xD000

lui $s6, 0x000C       
ori $s6, $s6, 0x2000        # $s6 = vram_graph = 0x000C2000 vga地址

jal init_graph              # 先初始化界面

read_kbd:
jal update_graph            # 每次读取ps2前先更新一下vga画面，主要是更新障碍物的位置
jal judge                   # 判断更新完位置的障碍物是否与tank相撞
addi $v0, $v0, -1           # 如果返回值为1，则减一后为0
beq  $v0, $zero, game_over  # 此时表明障碍物已经与tank相撞，游戏结束
lui  $s5, 0x8000            # $s5 = 0x80000000 $s5最高位为1，用于取出ps2的ready信号
addi $s4, $zero, 0x00F0     # $s4 = 0x000000F0 ，F0是断码的标志，是所有key的倒数第二个断码
lw   $t1, 0($s7)            # $t1 = {1'ps2_ready, 23'h0, 8'key}
and  $t2, $t1, $s5          # 取出$t1最高位的ready信号放到$t2上
beq  $t2, $zero, read_kbd   # $t2=0表示没有ps2输入，此时跳回去接着读read_kbd
andi $t2, $t1, 0x00FF       # 如果ready=1，取出$t1低八位的通码
beq  $t2, $s4, read         # 如果$t2=0x00F0，则说明读到了倒数第二个断码，此时跳到read来显示键盘码
j read_kbd  
read:                       # 读入最后一个断码，也就是key的标识码
lw   $t1, 0($s7)            # $t1 = {1'ps2_ready, 23'h0, 8'key}
and  $t2, $t1, $s5          # 同理，取出ready信号
beq  $t2, $zero, read_kbd   # ready=0，则回去重新读
andi $t2, $t1, 0x00FF       # 否则，取出低八位的断码(标识码)

addi $s1, $zero, 0x1d       # $s1 = "w"
beq  $t2, $s1, up           # if $t2 == "w", then tank remove up

addi $s1, $zero, 0x1b       # $s1 = "s"
beq  $t2, $s1, down         # if $t2 == "s", then tank remove down

addi $s1, $zero, 0x1c       # $s1 = "a"
beq  $t2, $s1, left         # if $t2 == "a", then tank remove left

addi $s1, $zero, 0x23       # $s1 = "d"
beq  $t2, $s1, right        # if $t2 == "d", then tank remove right

addi $s1, $zero, 0x44       # $s1 = "o"
beq  $t2, $s1, shot         # if $t2 == "o", then tank shot ballet

j read_kbd                  # 跳回重新读取ps2


# 初始化界面
init_graph:
addi $sp, $sp, -4
sw   $ra, 0($sp)
add  $t0, $zero, $s6        # $t0为全局变量，是当前点的地址，初始化为第一个点的地址
add  $t1, $zero, $zero      # $t1表示当前扫描到的y坐标
add  $t2, $zero, $zero      # $t2表示当前扫描到的x坐标
loop_y_init:                # 每一行的遍历
slti $t3, $t1, 480          # 如果$t1=y>=480，则整个屏幕都已经遍历完了，结束扫描
beq  $t3, $zero, end_y_init        
add  $t2, $zero, $zero      # $t2=x重新初始化为当前行的第一个点坐标
loop_x_init:  
slti $t3, $t2, 640          # 如果$t2=x>=640，则当前行已经遍历完了，切换到下一行
beq  $t3, $zero, end_x_init
addi $s0, $zero, 0x00F0     # 给$s0颜色赋值,点为绿色，注意只有前16位才是rgb有效位
sh   $s0, 0($t0)            # 把$s0的前16位rgb放到当前点的地址上，后16位全0，不作使用
addi $t0, $t0, 2            # offset+=2，每个点占2byte
addi $t2, $t2, 1            # $t2=x++
j loop_x_init               # 继续遍历该行的剩余点
end_x_init:
addi $t1, $t1, 1            # $t1=y++
j loop_y_init               # 继续遍历下一行
end_y_init:
addi $a0, $zero, 320        # 在初始位置(320,479)绘制tank
addi $a1, $zero, 479
jal tank
lw   $ra, 0($sp)
addi $sp, $sp, 4
jr   $ra                    # 遍历完成，返回地址


# 绘制tank
# input: $a0=x, $a1=y, 其中(x,y)为tank最下方中心点位置
tank:
addi $sp, $sp, -12
sw   $a0, 8($sp)
sw   $a1, 4($sp)
sw   $ra, 0($sp)
add  $s1, $a1, $zero        # 保存input的(x,y)信息
add  $s2, $a0, $zero
addi $s0, $zero, 0x0F00     # tank为红色
addi $a0, $s2, -30          # tank body: (x-30,y-20)~(x+30,y)
addi $a1, $s1, -20
addi $a2, $s2, 30
add  $a3, $s1, $zero 
jal draw_rectangle          # 绘制tank body
addi $a0, $s2, -10          # tank head: (x-10,y-40)~(x+10,y-20)
addi $a1, $s1, -40
addi $a2, $s2, 10
addi $a3, $s1, -20
jal draw_rectangle          # 绘制tank head
lw   $ra, 0($sp)
lw   $a1, 4($sp)
lw   $a0, 8($sp)
addi $sp, $sp, 12
jr $ra

# 绘制障碍物
# input: $a0=x, $a1=y, 其中(x,y)为obstacle最上方中心点位置
obstacle:
addi $sp, $sp, -12
sw   $a0, 8($sp)
sw   $a1, 4($sp)
sw   $ra, 0($sp)
add  $s1, $a1, $zero        # 保存input的(x,y)信息到($s2,$s1)
add  $s2, $a0, $zero 
addi $a0, $s2, -20          # 左上角($s2-20,$s1)
addi $a1, $s1, $zero
addi $a2, $s2, 20           # 右下角($s2+20,$s1+40)
addi $a3, $s1, 40
jal draw_rectangle
lw   $ra, 0($sp)
lw   $a1, 4($sp)
lw   $a0, 8($sp)
addi $sp, $sp, 12
jr $ra

# 画一个长方形(只会改变这个长方形范围内的像素值)
# input ($a0,$a1)=左上角坐标， ($a2,$a3)=右下角坐标
# input $s0=长方形颜色
draw_rectangle:
addi $sp, $sp, -4
sw   $ra, 0($sp)
add  $t0, $zero, $s6        # $t0表示当前点的地址，初始化为第一个点的地址
add  $t1, $zero, $zero      # $t1表示当前扫描到的y坐标
add  $t2, $zero, $zero      # $t2表示当前扫描到的x坐标
loop_y_rec:                 # 每一行的遍历
slti $t3, $t1, 480          # 如果$t1=y>=480，则整个屏幕都已经遍历完了，结束扫描
beq  $t3, $zero, end_y_rec        
add  $t2, $zero, $zero      # $t2=x重新初始化为当前行的第一个点坐标
loop_x_rec:  
slti $t3, $t2, 640          # 如果$t2=x>=640，则当前行已经遍历完了，切换到下一行
beq  $t3, $zero, end_x_rec
slt  $t3, $t2, $a0          # 如果x的范围不在矩形框内，则直接x++
bne  $t3, $zero, jump_x_rec
slt  $t3, $a2, $t2
bne  $t3, $zero, jump_x_rec
slt  $t3, $t1, $a1          # 如果y的范围不在矩形框内，则直接x++(放在这个循环内是为了让offset $t0也得到更新)
bne  $t3, $zero, jump_x_rec
slt  $t3, $a3, $t1
bne  $t3, $zero, jump_x_rec
# addi  $s0, $zero, 0x0F00  # $s0由参数传进 
sh   $s0, 0($t0)            # 把$s0的前16位rgb放到当前点的地址上，后16位全0，不作使用
jump_x_rec:
addi $t0, $t0, 2            # offset+=2，每个点占2byte
addi $t2, $t2, 1            # $t2=x++
j loop_x_rec                # 继续遍历该行的剩余点
end_x_rec:                  # 该行遍历结束
addi $t1, $t1, 1            # $t1=y++
j loop_y_rec                # 继续遍历下一行
end_y_rec:                  # 所有行遍历结束
lw   $ra, 0($sp)
addi $sp, $sp, 4
jr $ra


# 将输入的xy坐标转化为实际地址
# input: (x=$a0,y=$a1)
# output: $v0=address
coordinate_to_address:
addi $sp, $sp, -4
sw   $ra, 0($sp)
add  $t0, $zero, $s6        # $t0是当前点的地址，初始化为第一个点的地址
add  $t1, $zero, $zero      # $t1=y=0
loop_y:
slt  $t3, $t1, $a1 
beq  $t3, $zero, end_y
addi $t0, $t0, 1280         # 640*2=1280 每一行640个点，每个点2byte,即更新$t0为下一行第一个点的位置
addi $t1, $t1, 1            # $t1=y++
j loop_y
end_y:
add  $t0, $t0, $a0          # offset_x=2*x
add  $t0, $t0, $a0          # $t0已经是(x,y)点的实际地址
add  $v0, $t0, $zero
lw   $ra, 0($sp)
addi $sp, $sp, 4
jr   $ra

update_graph:
jr $ra

judge:
jr $ra

game_over:
jr $ra

up:
jr $ra

down:
jr $ra

left:
jr $ra

right:
jr $ra

shot:
jr $ra
