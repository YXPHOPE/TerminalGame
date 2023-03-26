# 俄罗斯方块游戏，作者YXP，版本V2.9.0
# 进行了多语言尝试
# 下一步更新：getKey和定点输出
use strict;
use warnings;
use utf8;
eval('use open":encoding(gbk)",":std";')
  if $^O eq 'MSWin32';
# 学院linux系统的$^O为'linux'，是老版本perl，不需要这句。此外这样判断能防止VScode中插件的一个bug
use Encode;
use Encode::CN;
use Time::HiRes qw/sleep/;
use Time::HiRes qw/time/;
use POSIX;
use Module::Load;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
checkModule('Term::ReadKey');
use Term::ReadKey;    # 初始未安装
our ( $DEBUG,  $VERSION, $LANG ) = ( 0, '2.9.0', 'zh-cn' );
our ( $HEIGHT, $WIDTH,   $TypeNum, $Mode ) = ( 18, 10, 0 );
our ( $Now,    $Next,    $Loc,     $Pause );
our %CONFIG = ( 'Line', 0, 'Mode', 2, 'Speed', 1, 'Grade', 0, 'mode', 0, );
our @scoreLine = (0,10,30,50,80);
our $cls    = $^O eq 'MSWin32' ? "cls" : 'clear';
our ($N,$v0) = (1,2.71828182845905**3);

for (@ARGV) {
    if ( m/^-\?$/ || m/^-h$/ || m/^\-\-help$/ ) {
        print(
"Game Tetris compiled by perl.\nOptions(All optional):\n    en|zh-cn  # language \n    -d|D|--debug   # debug game\n    digit   # initial speed, 1 default\n    -?|-h|--help  # help info"
        );
        exit();
    }
    if    (/^en$/)                             { $LANG  = 'en' }
    elsif ( /^--?debug$/ || /^-?d$/ || /^D$/ ) { $DEBUG = 1; }
    elsif (/^zh-cn$/)                          { $LANG  = 'zh-cn' }
    elsif (/^\d+$/) { $v0 = 2.71828182845905**($_+2); }
}
our @iprt = (
    '',     'mode',   'Speed', 'Grade', 'Line', '',
    'exit', 'rotate', 'movex', 'downy'
);

# W旋转ASD移动P退出
# 模式1简单不加速，2简单加速，3困难加速，4困难加速（困难为预测你最需要的那一个并适当减小其概率,暂未完成，目前困难为加速度大）
our $ENCD  = { 'en', 'utf-8', 'zh-cn', 'gbk' };
our %STYLE = (
    'b',  'bold',      'i', 'italic',
    'u',  'underline', 'c', 'cyan',
    'l',  'blue',      'h', 'black',
    'y',  'yellow',    'g', 'green',
    'r',  'red',       'm', 'magenta',
    'w',  'white',    ##S以上为文字属性、颜色，以下为背景颜色E##
    'ob', 'on_black', 'or', 'on_red',
    'og', 'on_green', 'oy', 'on_yellow',
    'ol', 'on_blue',  'om', 'on_magenta',
    'oc', 'on_cyan',  'ow', 'on_white',
);                    ##S颜色属性的简写，用于&prtfmt E##

# 旋转有4个请不要变并补齐,即使重复. 虽然做个旋转函数也不难，但是在有限种块的情况下，直接列出更快
# 可自由添加模块增加难度与趣味性
my $I = [
    [ [], [ 1, 1, 1, 1 ] ],                                    # 横棍
    [ [ 0, 0, 1 ], [ 0, 0, 1 ], [ 0, 0, 1 ], [ 0, 0, 1 ] ],    # 竖棍
    [ [],       [], [ 1, 1, 1, 1 ] ],
    [ [ 0, 1 ], [ 0, 1 ], [ 0, 1 ], [ 0, 1 ], ]
];

# 斜线
my $X = [
    map {
        (
            [ [1], [ 0, 1 ], [ 0, 0, 1 ], [ 0, 0, 0, 1 ] ],
            [ [ 0, 0, 0, 1 ], [ 0, 0, 1 ], [ 0, 1 ], [1] ]
        )
    } ( 0 .. 1 )
];
my $L1 = [
    [ [1],         [ 1, 1, 1 ] ],
    [ [ 0, 1, 1 ], [ 0, 1 ],    [ 0, 1 ] ],
    [ [],          [ 1, 1, 1 ], [ 0, 0, 1 ] ],
    [ [ 0, 1 ],    [ 0, 1 ],    [ 1, 1 ] ],
];
my $L2 = [
    [ [ 0, 0, 1 ], [ 1, 1, 1 ] ],
    [ [ 0, 1 ],  [ 0, 1 ],    [ 0, 1, 1 ] ],
    [ [],        [ 1, 1, 1 ], [1] ],
    [ [ 1, 1, ], [ 0, 1 ],    [ 0, 1 ] ]
];
my $O = [ map { [ [ 1, 1 ], [ 1, 1 ] ] } ( 0 .. 3 ) ];
my $S = [
    [ [ 0, 1, 1 ], [ 1, 1, ] ],
    [ [ 0, 1 ], [ 0, 1, 1 ], [ 0, 0, 1 ] ],
    [ [],       [ 0, 1, 1 ], [ 1, 1 ] ],
    [ [1],      [ 1, 1, ],   [ 0, 1 ] ],
];
my $T = [
    [ [ 0, 1 ], [ 1, 1, 1 ] ],
    [ [ 0, 1 ], [ 0, 1, 1 ], [ 0, 1 ] ],
    [ [],       [ 1, 1, 1 ], [ 0, 1 ] ],
    [ [ 0, 1 ], [ 1, 1 ],    [ 0, 1 ] ]
];
my $Z = [
    [ [ 1, 1 ], [ 0, 1, 1 ] ],
    [ [ 0, 0, 1 ], [ 0, 1, 1 ], [ 0, 1 ] ],
    [ [],          [ 1, 1 ],    [ 0, 1, 1 ] ],
    [ [ 0, 1 ],    [ 1, 1 ],    [1] ],
];
our ( $Live, $Down, $Board, $Block ) = ( 1, 0 );
our $STR = {
    'welcome',
    {
        'en',
"Welcome to the Tetris Game! Enter a number to start.\n1. Simple\n2. General\n3. Difficult\n4. Nightmare",
        'zh-cn',
"俄罗斯方块游戏！按下数字选择模式后开始游戏。\n1. 简单（无对角线形状，不加速）\n2. 一般（无对角线形状，有加速）\n3. 困难（有对角线，速度为2.5,）\n4. 噩梦（有对角线，速度增加较快）"
    },
    'status',
    { 'en', "Speed = %d\tScore = %d", 'zh-cn', "速度=%d\t得分=%d" },
    'over',
    { 'en', "Game over! Your score is %d", 'zh-cn', '游戏结束！您的得分为 %d' },
    'simple',
    { 'en', 'Simple', 'zh-cn', '简单' },
    'general',
    { 'en', 'General', 'zh-cn', '一般' },
    'difficult',
    { 'en', 'Difficult', 'zh-cn', '困难' },
    'nightmare',
    { 'en', 'Nightmare', 'zh-cn', '噩梦' },
    'Speed',
    { 'en', 'Speed: %.2f', 'zh-cn', '速度：%.2f' },
    'Grade',
    { 'en', 'Score: %%{b&y}%d%%', 'zh-cn', '得分：%%{b&y}%d%%' },
    'mode',
    { 'en', 'Mode : %s', 'zh-cn', '模式：%s' },
    'nextone',
    { 'en', 'Next', 'zh-cn', '下一个' },
    'Line',
    { 'en', 'Line : %d', 'zh-cn', '消行：%d' },
    'exit',
    { 'en', 'Pause : P 5 0', 'zh-cn', '暂停：P 5 0' },
    'paused',
    {
        'en',    'Paused, again to exit or continue.',
        'zh-cn', '已暂停，再按一次退出，其他则继续。'
    },
    'rotate',
    { 'en', 'Rotate: W 2', 'zh-cn', '旋转：W 2' },
    'movex',
    { 'en', 'MoveX : 4A D6', 'zh-cn', '左右：4A D6' },
    'downy',
    { 'en', 'DownY : S 8', 'zh-cn', '下移：S 8' },
    'overc',
    { 'en', 'Over  : O', 'zh-cn', '结束：O' },
    'lackheight',{'en','Terminal Size is not enough!','zh-cn','终端大小不足！'}
};
our ($wchar, $hchar);
sub init {
    ($wchar, $hchar) = GetTerminalSize();
    if($hchar<20 || $wchar<30){prt('lackheight');exit()}
    prt('welcome');
    ReadMode 0;
    while (1) {
        my $in = substr( <STDIN>, 0, -1 );
        if ( $in =~ /^[1-4]$/ ) {
            $CONFIG{'Mode'} = $in;
            last;
        }
        elsif ( $in eq '0' || $in eq '' ) {
            exit();
        }
        else {
            print("\033[1A\033[2K1-4: ");
        }
    }

    my $level = [ 0, 'simple', 'general', 'difficult', 'nightmare' ];
    $Mode = prt( 0, $level->[ $CONFIG{'Mode'} ] );
    $CONFIG{'mode'} = $Mode;

    # 越难狗屎玩意儿越多，宝贝越少. 简单没有$X
    my $q = 5 - $CONFIG{'Mode'};
    $Block = [
        ( map { $X } ( ($CONFIG{'Mode'}>3?$CONFIG{'Mode'}:3) .. $CONFIG{'Mode'} ) ),
        ( map { $L1 } ( 0 .. $q ) ),
        ( map { $L2 } ( 0 .. $q ) ),
        ( map { $I } ( 0 .. 4 - $CONFIG{'Mode'} ) ),
        ( map { $O } ( 0 .. $q ) ),
        ( map { $T } ( 0 .. $q ) ),
        ( map { $Z } ( 0 .. $q ) ),
        ( map { $S } ( 0 .. $q ) ),
    ];
    $TypeNum = @$Block + 0;
    ( $Now, $Next, $Loc ) = (
        [ ranint($TypeNum), ranint(4) ],
        [ ranint($TypeNum), ranint(4) ],
        [ -1,               int( $WIDTH / 2 - 1 ) ]
    );
    $Pause = 20 - $CONFIG{'Mode'}**2;    # 暂停次数
}

# 暂时不做样式
our %style = ( 'fix', { 'symbol', ' ', 'style', [] } );

sub prt {
    my ( $str, $f ) = ( shift, 1 );
    if ( $str eq '0' ) { $f = 0; $str = shift }
    if ( $str eq '' )  { return '' }
    $str = $STR->{$str}{$LANG} ? $STR->{$str}{$LANG} : $STR->{$str}{'en'};

    # $str = encode( $ENCD->{$LANG}, $str );

    $str = defined $_[0] ? sprintf( $str, @_ ) : sprintf($str);
    print $str. "\n" if $f;
    $str;
}

sub toord {
    my $s = shift;
    my $r = '';
    for ( 0 .. length($s) - 1 ) {
        $r .= ord( substr( $s, $_, 1 ) );
    }
    return $r;
}

sub main {
    system($cls);
    &init;
    ReadMode 3;
    my $ac = 0;    #ac是加速度
    if    ( $CONFIG{'Mode'} == 2 ) { $ac = 1.2; }
    elsif ( $CONFIG{'Mode'} == 3 ) { $ac = 1.5 }
    elsif ( $CONFIG{'Mode'} == 4 ) { $ac = 3; $WIDTH = 12;$HEIGHT=22; }
    $CONFIG{'Speed'} = log( $v0 + ($ac?($CONFIG{'Line'}**$ac):0) ) - 2;
    show();
    my ($t,$next, $key, $key2, $key3,$n,$d);
    my @a = ( 'W', 'S', 'D', 'A' );
    $t = time();    
    print("\033[?25l"); # 隐藏光标
    while ($Live) {    # 每一秒为单位重复此过程
        if ($Down) {    # 如果上一块落底则再生成一个
            $N++;
            $Now  = $Next;
            $Next = [ ranint($TypeNum), ranint(4) ];    # 随机一个形状，随机转过角度
            $Loc  = [ -1, int( $WIDTH / 2 - 2 ) ];      # 位置回到上面中间点
            $Down = 0;
            $CONFIG{'Speed'} = log( $v0 + ($ac?($CONFIG{'Line'}**$ac):0) ) - 2;
            show();
        }
        $t +=1 / $CONFIG{'Speed'}; # 此处修正了计时器
        ( $next, $key, $key2, $key3 ) = (1,undef,undef,undef);
        while ( time() < $t) {
            # ReadKey在循环时别用-1，否则会造成大量资源浪费，使用最高反应速度所需的时间即可
            if   ($next) { $key  = ReadKey(0.05); }
            else         { $next = 1; }
            if ( defined $key ) {
                # 左 27 91 68
                # 上 27 91 65
                # 右 27 91 67
                # 下 27 91 66
                if ( ord($key) == 27 ) {
                    $key2 = ReadKey(-1);
                    $key3 = ReadKey(-1);
                }
                if ( $key2 && ord($key2) == 91 && $key3 ) {
                    $n = ord($key3);
                    if ( $n >= 65 && $n <= 68 ) {
                        $key = $a[ $n - 65 ];
                    }
                }
                $_ = uc($key);
                if (/^[2W]$/) {    #旋转，只有4个角度，防止超过3
                    $Now->[1]++;
                    $Now->[1] %= 4;

                    # 旋转时防止碰到已有方块
                    if ( !writeloc(-2) ) {
                        $Now->[1]--;
                        $Now->[1] %= 4;
                        next;
                    }

                    # 旋转时防止越界
                    elsif ( $Loc->[1] < 0 || $Loc->[1] > $WIDTH - 5 ) {
                        $d = $Loc->[1] < 0 ? 1 : -1;
                        until ( writeloc(-1) ) { $Loc->[1] += $d; }
                    }
                }
                elsif (/^[AD46]$/) {
                    $d = /[A4]/ ? 1 : -1;
                    $Loc->[1] -= $d;    #此处需要检查
                    if ( !writeloc(-2) ) {
                        $Loc->[1] += $d;
                        print "#key=$_\n" if $DEBUG;
                        next;           # 与上次相同跳过显示
                    }
                    elsif ( !writeloc(-1) ) { $Loc->[1] += $d; next; }
                }
                elsif (/^[S8]$/) {
                    $Loc->[0]++;
                }
                elsif ( /^[P0]$/ && $Pause ) {
                    $Pause--;
                    prt 'paused';
                    my $in = ReadKey(-1);
                    until ( defined $in && uc($in) =~ /^[WASD2468P0]$/ ) {
                        $in = ReadKey(0.2);
                    }
                    if ( uc($in) =~ /^[P0]$/ ) { $Live = 0; last; }
                    else { $key = uc $in; $next = 0; next; }
                }
                elsif (/^O$/) { $Live = 0; last; }
                if    (/^[WASD2468]$/) {
                    print "#key=$_\n" if $DEBUG;
                    show();
                }
                if ( /^[S8]$/ && $Down ) { last; }    # 自己下移到底结束循环
            }
        }

        # while循环完毕一秒已过，下移一位
        if    ($Down) { next; }
        elsif ($Live) {
            print "#FreeDown\n" if $DEBUG;
            $Loc->[0]++;
            show();
        }
    }
    # 恢复光标
    print("\033[?25h");
    prt 'over', $CONFIG{'Grade'};
    ReadMode 0;
}

sub show {
    writeloc(1);
    my ( $out, $tmp ) = ( '', '' );
    my $Nex = $Block->[ $Next->[0] ][ $Next->[1] ];
    print "Nex=" . prtcode($Nex) . "\n" if $DEBUG;
    foreach my $i ( 0 .. $HEIGHT - 1 ) {
        $out .= '|';
        foreach my $j ( 0 .. $WIDTH - 1 ) {
            if   ( $Board->[$i][$j] ) { $tmp .= "  " }
            else                      { $tmp .= "00" }
        }
        if ( $i == $HEIGHT - 1 ) {
            $tmp =~ s/( +)/%{u&og}$1%/g;
            while ( $tmp =~ /0/ ) {
                $tmp =~ /(0+)/;
                my $x = '_' x length($1);
                $tmp =~ s/0+/%{u}$x/;
            }
            $tmp .= '%';

            # print $tmp;
        }
        else {
            $tmp =~ s/( +)/%{og}$1%/g;
            $tmp =~ s/0/ /g;
        }
        $out .= ( $tmp . '|   ' );
        my $r = '';
        if    ( $i == 0 ) { }
        elsif ( $i == 1 ) { $r = prt( 0, 'nextone' ) }    #给第一行后面加上Next one
        elsif ( $i <= 5 ) {
            my $row = $Nex->[ $i - 2 ];
            if ( defined $row && @$row ) {
                foreach (@$row) {
                    $r .= $_ ? '  ' : '00';
                }
                $r =~ s/( +)/%{oc}$1%/g;
                $r =~ s/0/ /g;
            }
        }
        elsif ( $i <= 15 ) {
            $r = prt(
                0,
                $iprt[ $i - 6 ],
                (
                    ( exists $CONFIG{ $iprt[ $i - 6 ] } )
                    ? $CONFIG{ $iprt[ $i - 6 ] }
                    : undef
                )
            );
        }
        elsif ( $i == 16 && !$Pause ) { $r = prt( 0, 'overc' ) }
        elsif ( $i == $HEIGHT )       { }
        $out .= "$r\n";
        $tmp = "";
    }
    if ( !$DEBUG ) { system($cls); }
    print(  'board='
          . prtcode($Board)
          . "\nloc="
          . prtcode($Loc)
          . "\tNow="
          . prtcode($Now)
          . "\tDown=$Down\nblock="
          . prtcode( $Block->[ $Now->[0] ][ $Now->[1] ] )
          . "\n" )
      if $DEBUG;
    prtfmt($out);
    writeloc(0) unless $Down;
}

sub judge {
    my ( $f, @row ) = 1;
    my $first;
    foreach my $i ( 0 .. $HEIGHT - 1 ) {
        foreach ( 0 .. $WIDTH - 1 ) {
            if ( !$Board->[$i][$_] ) { $f = 0; last; }
        }
        if ($f) { unshift @row, $i; }
        $f = 1;
    }
    if (@row) {
        print "get score, line = @row, length = " . ( @$Board + 0 ) . "\n"
          if $DEBUG;

        # 之前是从前向后删，不行，因为改变了后面的行序号,这里可以改为前面unshift或者这里reverse
        foreach (@row) { splice( @$Board, $_, 1 ) }
        my @new = map { []; } 0 .. $#row;
        splice( @$Board, 0, 0, @new );    # 在board头部插入对应数量的空行
        $CONFIG{'Grade'} += $scoreLine[@row];
        $CONFIG{'Line'}  += @row;
    }
}

sub writeloc {
    my $m = shift;    # 0擦除上一次写入，1写入以供show，-1判断是否出界不写入面板, 2固化时用2
    my $O = $Block->[ $Now->[0] ][ $Now->[1] ];    # 读取该形状该角度下的坐标信息
    print "writeloc($m)" . prtcode($O) . "\n" if $DEBUG;
    print "i,j=@_\n"                          if @_ && $DEBUG;
    @_ = ( 3, 3 )                             if !@_;
    foreach my $i ( 0 .. $_[0] ) {
        if ( $O->[$i] ) {
            foreach my $j ( 0 .. 3 ) {
                if ( $O->[$i][$j] )
                { # Modification of non-creatable array value attempted, subscript -4 at Tetris.pl line
                    if ( $i == $_[0] && $j == $_[1] + 1 ) { return 0; }
                    $i += $Loc->[0];
                    $j += $Loc->[1];
                    if ( $i < 0 ) {    # 当有在第一行上方未能显示的块时
                        if    ( $m == -1 ) { next; }                 # 如果只是测试则通过
                        elsif ( $m == 2 )  { $Live = 0; return 0; }  # 如果是固化则失败
                    }

                    # 检查左右是否出界,左右移动时横向坐标越界直接返回0
                    if ( $m == -1 ) {
                        if ( $j < 0 || $j > $WIDTH - 1 ) { return 0; }    # 碰壁了
                    }
                    elsif ( $m == -2 ) {
                        if ( $i >= 0 && $Board->[$i][$j] ) { return 0; }
                    }    # 与已有块冲突
                    elsif ( $i >= 0 && $m != -1 ) {  # 到了最下面i>0是为了使在最上面时未进入面板中的块
                         # if($m == 0 && $Down && ($Board->[$i][$j] || $i >= $HEIGHT)){return 0; }# 为下面移除坐标时到这里就停止（移除同样多已写入的）,防止移除过多未写入的部分
                        if ( $m == 1
                            && ( $i >= $HEIGHT || $Board->[$i][$j] ) )
                        {
                            $Live = 0 if $i == 0;    # 在第一行碰到就是game over
                            print "#Reach down! \$i=$i\n" if $DEBUG;
                            $Down = 1;
                            writeloc( 0, $i - $Loc->[0], $j - $Loc->[1] - 1 )
                              ;                      # 回撤已写内容
                            $Loc->[0]--;             #此刻实际已过头，故而回到上一行位置，再固化
                            writeloc(2);
                            judge();
                            return 1;
                        }    # 写入存在1时下面有方块存在
                        $Board->[$i][$j] = $m;    # 向面板中写入方块位置存在或者不存在
                        print "\$i=$i;\$j=$j;\$Down=$Down\n" if $DEBUG;
                    }
                    $i -= $Loc->[0];              # !!!归位，下一个还要用
                }
            }
        }
    }
    return 1;
}
sub ranint { int( rand( $_[0] ) ); }

sub ranred {
    my @red = qw/or og oy ol om oc ow/;
    return $red[ ranint( $#red + 1 ) ];
}

sub prtcode {
    my ( $r, $out ) = ( ref $_[0], "" );
    if ( $r eq '' && defined $_[0] ) {
        $out = $_[0] =~ /^-?\d+(\.\d+)?$/ ? $_[0] : "'$_[0]'";
    }
    elsif ( $r eq 'ARRAY' ) {
        my @arr = @{ $_[0] };
        foreach my $i (@arr) {
            $out .= ( prtcode($i) . "," );
        }
        $out = "[" . substr( $out, 0, -1 ) . "]";
    }
    elsif ( $r eq "HASH" ) {
        my %hash = %{ $_[0] };
        foreach ( sort keys %hash ) {
            $out .= ( "'$_'," . prtcode( $hash{$_} ) . "," );
        }
        $out = "{" . substr( $out, 0, -1 ) . "}";
    }
    else {
        $out = "''";
    }
    $out;
}

sub prtfmt
{ ##S printformatted格式化输出,prtfmt("|+|{样式}内容|+|","全局样式",可选"正则表达式 样式"), 注意正则表达式将会截断原来的分隔。例如：prtfmt("{b&y}|+|head|+|{c&ol}middle|+|footer\n",'g','e r');E##
    my ( $bre, $br ) =
      ( '%', '%' );    # 定义分隔符 可以修改为其他，不过得符合正则表达式的语法,前一个用于匹配，后一个用于替换为
    my ( $str, $presty ) = @_;
    $presty = defined($presty) ? $presty . '&' : '';
    foreach my $i ( 2 .. $#_ ) {
        my @ss = split( ' ', $_[$i] );
        $str =~ s/($ss[0])/${br}{$ss[1]}$1$br/g;    # 第二个起后面的所有正则表达式全部遍历
    }
    if ( $str !~ /$bre\{/ && !$presty ) {
        print "$str";
        return 1;
    }
    $str =~ s/($bre\{[^\}]+\})/$1$br/g;             # 添加分隔符用于分割不同样式的内容
    my @arr = split( /$bre/, $str );                # 分隔符没了
    my $n   = 0;
    while ( $n < @arr ) {
        my ( $x, $stystr, $flag ) = ( $arr[$n], $presty, 1 );
        if ( $x =~ /^\{[a-z\&]+\}$/ ) {
            $stystr .= $x;
            $stystr =~ s/\{|\}//g;
            $flag = 2;                              # 样式，由flag控制输出下一个片段
        }
        my $out = $arr[ $n + $flag - 1 ];
        if ( $stystr ne '' ) {
            my @styarr = split( '&', $stystr );
            my @sty    = map {
                next if $_ =~ /^ *$/;
                my $s = $STYLE{$_};
                $s if $s;
            } @styarr;
            print colored( [@sty], $out );          # 在传入参数前请自行转换编码格式
        }
        else { print $out; }
        $n += $flag;
    }
}

sub checkModule {
    my $module = shift;
    use Module::Load;
    if ( !eval("load $module;1") ) {
        print "$module not installed, installing...\n";
        if    ( $^O eq 'linux' )   { print system("cpanm $module") }
        elsif ( $^O eq 'MSWin32' ) { print system("cpan install $module") }
        if    ( !eval("load $module;1") ) {
            print
"Can't load $module, you may need to execute the command below:\ncpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)\nThen try again.";
        }
        die 'Please run this program again.';
    }
}

ReadMode 3;
main();
ReadMode 0;

