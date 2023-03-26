use strict;
use warnings;
use utf8;
eval('use open":encoding(gbk)",":std";') if $^O eq 'MSWin32';
use Time::HiRes qw/sleep/;
use Time::HiRes qw/time/;
use Term::ReadKey;
use Term::ANSIColor;                ##S带颜色输出E##
use Term::ANSIColor qw(:constants);
use POSIX qw/log10/;
use Encode;
use Encode::CN;
our $VERSION = '2.0.1';
our $update_log = '
v1.0.1: 创建了基础运行
v1.1.1: 添加样式支持
v1.2.1: 修复了头尾相连时判断为死亡的bug
v1.5.1: 升级了按键支持，WASD、方向键
v2.0.1: 升级了终端显示方式，改为按光标位置覆盖要改变位置的内容
';
$Term::ANSIColor::AUTORESET = 1;    ##S自动为下一句去除颜色设定E##
our ( $Width, $Height,$x0,$y0 ) = ( 10, 10,4,1 );
our %style = (
    'b',  'bold',      'i', 'italic',
    'u',  'underline', 'c', 'cyan',
    'l',  'blue',      'h', 'black',
    'y',  'yellow',    'g', 'green',
    'r',  'red',       'm', 'magenta',
    'w',  'white',                  ##S以上为文字属性、颜色，以下为背景颜色E##
    'ob', 'on_black', 'or', 'on_red',
    'og', 'on_green', 'oy', 'on_yellow',
    'ol', 'on_blue',  'om', 'on_magenta',
    'oc', 'on_cyan',  'ow', 'on_white',
);                                  ##S颜色属性的简写，用于&prtfmt E##
our @bg    = ();
our @snake = ();
our ( $score, $food, $speed,$v0, $alive ) = ( 0, 0, 1,1, 1 );    # 长度、食物、速度、存活
our $full   = $Width * $Height;
our %direct = (
    UP    => [ -1, 0 ],
    DOWN  => [ 1,  0 ],
    LEFT  => [ 0,  -1 ],
    RIGHT => [ 0,  1 ],
);                                                         # 移动方向
our $head = 'RIGHT';                                       # 初始移动方向
our ( $cur, $key ) = $head;
our %arrow = (
    'UP',    '|+|{y}▲|+|',    'DOWN',  '|+|{y}▼|+|',  'LEFT',  '|+|{y}＜|+|',
    'RIGHT', '|+|{y}＞|+|',   'POINT', '|+|{l}＋|+|', 'SNAKE', '|+|{y}■|+|',
    'FOOD',  '|+|{b&y}⊙|+|', 'TAIL',  '|+|{g}●|+|'
);
our $flag = 0;
our ($ti, $wchar, $hchar, $left_space, $left,$mid);

our $KEY = {
    0,'',
    8,'BACKSPACE',
    9,'TAB',
    10,'enter',
    13,'ENTER',
    27,{
        0,'ESC',
        91,{
            49,{126,'HOME'},
            50,{126,'INSERT'},
            51,{126,'DELETE'},
            52,{126,'END'},
            65,'UP',
            66,'DOWN',
            67,'RIGHT',
            68,'LEFT'
        },
        79,{
            121,'PAGEUP',
            115,'PAGEDOWN',
        }
    },
};
for (@ARGV) {
    if ( m/^-\?$/ || m/^-h$/ || m/^\-\-help$/ ) {
        print(
"Game Snake compiled by perl.\nOptions(All optional):\n    digit   # initial Speed, 1 default, max 5\n    -?|-h|--help  # help info"
        );
        exit();
    }
    elsif (/^\d+\.?\d*$/){$v0=$_>5?5:$_;}
    # elsif ( /^--?debug$/ || /^-?d$/ || /^D$/ ) { $DEBUG = 1; }
    # elsif (/^zh-cn$/)                          { $LANG  = 'zh-cn' }
    # elsif (/^\d+$/) { $CONFIG{'Line'} = $_; }
}
our %Style = (
'','0', # 默认
' ','0',
'h','1', # 高亮
'u','4', # 下划线
't','5', # 闪烁
'v','7', # 反显verse
'n','8', # 不可见none
'b','30', # 黑色前景
'r','31', # 红色前景
'g','32', # 绿色前景
'y','33', # 黄色前景
'l','34', # 蓝色前景(拼音l)
'p','35', # 紫色前景
'c','36', # 青色前景cyan
'w','37', # 白色前景
'bb','40', # 黑色背景
'br','41', # 红色背景
'bg','42', # 绿色背景
'by','43', # 黄色背景
'bl','44', # 蓝色背景
'bp','45', # 紫色背景
'bc','46', # 青色背景
'bw','47', # 白色背景
);
sub parseStyle {
    my $sty = shift;
    my $res = "\033[";
    for(split(/[\&;]/,$sty)){
        if (exists $Style{$_}){
            $res.=$Style{$_}.';';
        }
    }
    if($res eq "\033["){return ''}
    else{chop($res);return $res.'m';}
}
sub prtloc{
    my($x,$y,$s,$sty)=@_;
    $sty = (defined $sty)?parseStyle($sty):'';
    print("\033[$x;${y}H$sty$s\033[0m");
}
sub main {
    system($^O eq 'MSWin32'?'cls':'clear'); # 清屏以保证cmd效果
    &init;
    print("\033[?25l"); # 隐藏光标
    $ti = time();             
    ReadMode 3;
    $| = 0; # autoflash 非零时 输出通道上每次写入或打印后立即强制刷新
    while ($alive) {
        $speed = ( $speed < 8 ) ? ($speed<6?( $v0 + $score / 10 ):6+2*($score-(6-$v0)*10)/200) : 8;    # 速度控制
        if ( @snake == $full ) {
            print YELLOW"\nWOW 你通关啦！\n";    # 蛇占满游戏区时显示
            last;
        }
        else {
            &move;
            &check_head;
            my $n = 0;
            &show;
            if($alive eq '')    {print RED"啊哦...你把自己吃掉了\n"; last; }
            elsif($alive eq '0'){print RED"啊哦...你撞墙了\n"; last;}
        }
    }
    # 恢复光标
    print("\033[?25h");
    ReadMode 0;
}

sub init {
    print YELLOW"点阵大小（空格分开宽和高，默认10x10）\n";
    my $input = substr( <STDIN>, 0, -1 );
    ( $Width, $Height ) = split( /[, ，x]+/, $input )
      if $input =~ /^\d+[, ，x]+\d+$/;
    $Width  = $Width < 4  ? 8 : $Width;
    $Height = $Height < 4 ? 8 : $Height;
    my $y = int( $Height / 2 );
    $full = $Width * $Height;
    @bg   = map {
        my $x = $_;
        [ map { $bg[$x][$_] = $arrow{'POINT'} } 0 .. $Width - 1 ]
    } 0 .. $Height - 1;
    @{ $bg[$y] }[ 0, 1 ] = ( $arrow{'SNAKE'}, $arrow{$cur} );    # 初始蛇身位置
    @snake = ( [ $y, 1 ], [ $y, 0 ], );                          # 保存蛇身坐标
    &make_food;                                                  # 产生食物
}

sub show {
    if    ( $^O eq 'linux' )   { system('clear'); }
    elsif ( $^O eq 'MSWin32' ) { system("cls"); }
    $mid = ' 'x(6-int(log10($score||1)));
    prtfmt(
"|+|{g}得分: |+|{y&b}$score|+|{g}${mid}速度: |+|{r}$speed\n|+|{g}操作: WASD   退出: ESC\n"
    );
    # 操作 : WASD     退出 : Ctrl+c
    # ■▲■＋＋＋■＋＋＋
    my @out = map { join( '', @{ $bg[$_] } ) } 0 .. $#bg;
    my $out = "|+|{m}＿".'＿'x$Width."\n||+|".join( "|+|{m}▏\n||+|", @out );
    prtfmt( $out . "|+|{m}▏\n￣".'￣'x$Width."|+|\n", 'l' );#𝄀𝗹Іᑊऺ︲㆐❘̍｜I⃒▏│⎟၊▕⎸⃓ⵏꓲ￨⎮𓏤׀∣︳︱⎹⏐𐑦𐌠⸾╷౹ᛁ⎪ˌﺎ⎜⎢ᅵ̩ǀꟾ𐩽៲ㅣￜ𐰾ˈ꠰᱾╵ߊꞋ⍿꡶॑꒐𐊊𑁇𐤦।ᛧ𐌉꘡ᛌا𝄅𝇅᳜𐡆𝅥ﺍ𝇁>����Іᑊऺ︲㆐❘̍｜I⃒▏│⎟၊▕⎸⃓ⵏꓲ￨⎮��׀∣︳︱⎹⏐����⸾╷౹ᛁ⎪ˌﺎ⎜⎢ᅵ̩ǀꟾ��៲ㅣￜ��ˈ꠰᱾╵ߊꞋ⍿꡶॑꒐������।ᛧ��꘡ᛌا����᳜����ﺍ��
}

sub move {
    $cur = $head;
    $key = '';
    $flag = 1;
    $ti+=1-$speed*0.1;

#0    Perform a normal read using getc;-1(循环时非常占用资源)   Perform a non-blocked read;>0   Perform a timed read如果在非阻塞读取期间缓冲区中没有等待，则将返回 undef。在大多数情况下，您可能想要使用ReadKey -1.
# sleep(1.1-$speed*0.1+$ti-time()) if $key !~ /[wasdWASD]/;
    while ( time() < $ti) {
        $key = getKey(0.05)->{'key'};#ReadKey(0.02);
        if ( $key && $flag ) {
            # 不允许反向移动
            $key =~ tr/a-z/A-Z/;
            if ( $key eq 'UP'||$key eq 'W' ) {
                if ( $head ne 'DOWN' ) { $cur = 'UP' }
            }
            elsif ( $key eq 'LEFT' || $key eq 'A' ) {
                if ( $head ne 'RIGHT' ) { $cur = 'LEFT' }
            }
            elsif ( $key eq 'DOWN' || $key eq 'S' ) {
                if ( $head ne 'UP' ) { $cur = 'DOWN' }
            }
            elsif ( $key eq 'RIGHT' || $key eq 'D' ) {
                if ( $head ne 'LEFT' ) { $cur = 'RIGHT' }
            }
            elsif($key eq 'ESC'){
                print("ESC");
                exit();
            }
            $head = $cur;
            $flag = 0;
            # last; # 有此句则按下WASD将立即移动，没有此句则需等待到时间
        }
    }

    unshift @snake,
      [ $snake[0][0] + $direct{$cur}[0], $snake[0][1] + $direct{$cur}[1] ];
}

sub make_food {
    if ( @snake < $full ) {
        until ($food) {
            my ( $x, $y ) = ( int( rand($Width) ), int( rand($Height) ) );
            if ( $bg[$y][$x] eq $arrow{'POINT'} ) {
                $bg[$y][$x] = $arrow{'FOOD'};
                $food = 1;
            }
        }
    }
}

sub check_head {

    # 蛇身超出范围
    if (   $snake[0][0] < 0
        || $snake[0][0] > $Height - 1
        || $snake[0][1] < 0
        || $snake[0][1] > $Width - 1 )
    {
        $alive = '0';
        return 0;
    }

    # 蛇吃到自己
    if ( @snake > 3 ) {
        foreach ( 1 .. $#snake - 1 ) {
            if (   $snake[0][0] == $snake[$_][0]
                && $snake[0][1] == $snake[$_][1] )
            {
                $alive = '';
            }
        }
    }

    # 吃到食物
    if ( $bg[ $snake[0][0] ][ $snake[0][1] ] eq $arrow{'FOOD'} ) {
        $bg[ $snake[0][0] ][ $snake[0][1] ] = $arrow{$cur};
        $score++;
        $food = 0;
        &make_food;
        # print "snake:" . ( $#snake + 1 ) . "full:$full\n";
        push @snake, [ $snake[-1][0], $snake[-1][1] ]
          ;    # 新的蛇身放在尾部,此时尾部有两个相同的坐标，pop后刚好相当于尾巴不动，蛇头动
    }

    # prtloc($x0+$snake[0][0],$y0+$snake[0][1],'■','y');

    # 移动
    $bg[ $snake[0][0] ][ $snake[0][1] ] = $arrow{$cur};
    if ( !( $snake[-1][0] == $snake[0][0] && $snake[-1][1] == $snake[0][1] ) ) {
        $bg[ $snake[-1][0] ][ $snake[-1][1] ] = $arrow{'POINT'};
    }    # 先清除尾巴显示
    pop @snake;            # 去掉尾巴
    $bg[ $snake[$#snake][0] ][ $snake[$#snake][1] ] = $arrow{'TAIL'};
    map { $bg[ $snake[$_][0] ][ $snake[$_][1] ] = $arrow{'SNAKE'}; }
      1 .. $#snake - 1;    # 其他蛇身显示
    if($alive eq ''){$bg[ $snake[0][0] ][ $snake[0][1] ] = $arrow{$cur};}
}

sub prtfmt {
    my ( $str, $presty ) = @_;
    if ( $str !~ /\|\+\|\{/ && !$presty ) {
        print "$str";
        return 1;
    }
    $str =~ s/(\|\+\|\{[^\}]+\})/$1\|\+\|/g;
    my @arr = split( /\|\+\|/, $str );
    my $n   = 0;
    while ( $n < @arr ) {
        my ( $x, $stystr, $flag ) = ( $arr[$n], '', 1 );
        $stystr = $presty . '&' if $presty;
        if ( $x =~ /^\{[a-z\&]+\}$/ ) {
            $stystr .= $x;
            $stystr =~ s/\{|\}//g;
            $flag = 2;
        }
        my $out = $arr[ $n + $flag - 1 ];
        if ( $stystr ne '' ) {
            my @styarr = split( '&', $stystr );
            my @sty    = map {
                next if $_ =~ /^ *$/;
                my $s = $style{$_};
                $s if $s;
            } @styarr;
            print colored( [@sty], $out );
        }
        else { print $out; }
        $n += $flag;
    }
}

# 适用于输出英文半角字符的输入法下获取按键，返回值为键名的大写字母或数字本身或下符号
# 不判断shift，只能判断有限的ctrl，默认key为大写，原内容在input键
# 中文符号的bug暂未修复
sub getKey{
    my $t = shift; # 缓冲等待时间
    ReadMode 3;
    my @c = (ReadKey($t||0.02),ReadKey(-1),ReadKey(-1),ReadKey(-1),ReadKey(-1));
    ReadMode 0;
    $t = '';
    my $o=$KEY;
    my $key='';
    my $obj = {
        'ctrl',0,
        'key','',
        'input',''
    };
    for(0..$#c){
        if(defined $c[$_]){
            $t.=$c[$_];
            $c[$_]=ord($c[$_]);
            $o = $o->{$c[$_]};
            # print($o);
        }
        else{pop @c;}
    }
    # 如果t长度只有1位，直接判断ascii码范围，符合直接返回输入的内容大写
    if(length($t)==1 &&$c[0]&& $c[0]>31&&$c[0]<127){
        $key=uc($t);
    }
    elsif(length($t)==1 &&$c[0]&& $c[0]<32){
        $key = chr($c[0]+64);
        if($KEY->{$c[0]}){
            $key = ref($o)eq'HASH'?$o->{0}:$o;
            if($key=~/[a-z]+/){ # 小写代表是有ctrl键
                $key = uc($key);
                $obj->{'ctrl'} = 1;
            }
        }
        else{$obj->{'ctrl'}=1;}
    }
    else{$key = (ref($o)eq'HASH')?$o->{0}:$o;}
    if(!$key){$key='';}
    if($key eq'ESC' && @c>1){
        $key = ''; # 有时其他控制键可能误触发ESC
    }
    $obj->{'key'} = $key;
    $obj->{'input'} = $t;
    # print("\033[1A\033[8C@c - ".length($t)." $t\n");
    return $obj;
}
# main();

# # system('cls');
for my $x(0..9){
    for my $y(0..9){
        print($y);
    }
    print "\n";
}
prtloc(3,7,'v','h;y');
# prtloc(11,10,'');
# print("\033[3;5H\033[1;31m-\033[0m");
# print(parseStyle('g;bl')."0101\033[0m]");
# while(1){
#     my %x = %{getKey(5)};
#     print("$x{'ctrl'} $x{'key'}\n");
# }
# Ctrl+A-Z 为 1-26 由于Back8与Tab9、Enter13也在里边故应联合内容来判断Ctrl
# 27-31 Ctrl+[\] Ctrl+Shift+^-
# ctrl+enter=10