#!ruby -KS
#
# encoding:CP932
#
# 2015.06.10:KAWAI Toshikazu
# 総合支援センター（キャンパス自立支援室）のノートテイカー割り当てを
# 線形計画法を用いて行う。
# LP_SOLVEに入力するための式を作り出す
#
=begin
入力データ形式
データ形式
クラス情報,クラスNo,,,,,
テイカ—種別1必要人数,人数,,,,
テイカ—種別2必要人数,人数,,,,
,
,
テイカ—No,テイカ—種別,クラスへの希望度,,,
constraint:制約式
,
,
,

例
class:クラス数:1,2,3,4,5,6,7,8,9
type:PC:2,2,2,2,2,,,                          #type PC がクラス１で2名必要
type:HAND:1..2,1..2,1..2,1..2,1..2,,,         #1..2は1以上2以下
type:C:1,0,1,0,0,,,,
1:PC:5,0,3,1,3,,,
2:PC:2,3,4,5,1,0,,,
3:HAND:1,2,3,4,0,,
4:HAND:5,3,2,4,0,0,,,,
5:PC:5,0,3,1,3,,,
6:PC:2,3,4,5,1,0,,,
7:HAND:1,2,3,4,0,,
8:HAND:5,3,2,4,0,0,,,,
constraint:x_id_1 + x_id_2 + x_id_3 <= 1       #クラス1,2,3が同じ曜日時限
constraint:x_1_cl + x_4_cl <= 1                #テイカー1と4が同一人物
constraint:x_1_cl + x_2_cl <= 1                #テイカ—1と2は同じクラスに入れない
constraint_sum:x_2_cl <= 5                     #テイカー2の上限コマ数
constraint_sum:x_1_cl + x_4_cl <= 5            #テイカ—1（4と同一人物）の上限コマ数

1-4がベテラン、5-8が新人
constraint:x_5_cl + x_6_cl <= 1                #新人PCテイカ—だけにしない。

type文で、1..2は一人以上二人以下を示す。
constraint:(x_3_cl + x_4_cl) - (x_7_cl + x_8_cl) >= 0
にすれば新人が入ればベテランが入る。ベテラン2人になることもある。要らなければ手で削る。

=end

class LP_notetaker
  def initialize
    @cl_names = []
    @cl_num = nil
    @ty_names = []
    @ty_need  = {}
    @ty_members = Hash.new {|h, k| h[k] = []}
    @members  = {}
    @constraints = []
    @constraint_sums = []
    @weight = {'5' => 2000, '4' => 1900, '3' => 1700, '2' => 1400, '1' => 1000, '0' => -1000000}
  end
  def set_class(cl_num, names)
    @cl_num = cl_num.to_i
    @cl_names = names.split(/\s*,\s*/)
  end
  def add_type(name, needs)
    raise "type #{name} Redefined" if @ty_names.include? name
    @ty_names << name
    @ty_need[name] = needs.split(/\s*,\s*/, -1).map {|e| if e == '' then '0' else e end}
  end
  def add_member(id, ty, hopes)
    @ty_members[ty] << id
    @members[id] = hopes.split(/\s*,\s*/, -1).map {|e| if e == '' then '0' else e end}
  end
  def add_constraint(const)
    @constraints << const
  end
  def add_constraint_sum(const_sum)
    @constraint_sums << const_sum
  end

  def eq_max
    eq = []
    @members.keys.each {|id|
      @cl_names.each_index {|ix|
        eq << "#{@weight[@members[id][ix]]} x_#{id}_#{@cl_names[ix]}"
      }
    }
    eq.join(' + ') + ';'
  end
  def eq_int01
    eq = []
    eq01 = []
    @members.keys.each {|id|
      @cl_names.each {|cl|
        eq << "x_#{id}_#{cl}"
        eq01 << "x_#{id}_#{cl} >= 0;"
        eq01 << "x_#{id}_#{cl} <= 1;"
      }
    }
    eq01.join("\n") + "\n" + 'int ' +  eq.join(', ') + ";\n"

  end
  def eq_type_need
    eq = []
    @ty_names.each {|type|
      @ty_need[type].each_index {|ix|
        cl = @cl_names[ix]
        need = @ty_need[type][ix]
        eq_left = @ty_members[type].map {|m| "x_#{m}_#{cl}"}.join(' + ')
        low = high = '0'
        case need
        when /(\d+)\.\.(\d+)/
          low, high = $1, $2
        when /(\d+)/
          low = high = $1
        end
        if high == low
          eq << eq_left + ' = ' + low + ';'
        else
          eq << eq_left + ' >= ' + low + ';'
          eq << eq_left + ' <= ' + high + ';'
        end
      }
    }
    eq.join("\n")
  end
  def eq_constraint
    eq = []
    @constraints.each {|const|
      case const
      when /_id_/
        @members.keys.each {|id|
          eq << const.gsub('_id_', "_#{id}_") + ';'
        }
      when /_cl/
        @cl_names.each {|cl|
          eq << const.gsub('_cl', "_#{cl}") + ';'
        }
      end
    }
    eq.join("\n")
  end
  def eq_constraint_sum
    eq = []
    @constraint_sums.each {|const|
      m = />|>=|=|<=|</.match(const)
      eq_left = m.pre_match.strip
      eq_right = m.to_s + m.post_match
#      p eq_left
#      p eq_right
      eq_lefts = []
      case eq_left
      when /_id_/
        @members.keys.each {|id|
          eq_lefts << eq_left.gsub('_id_', "_#{id}_")
        }
      when /_cl/
        @cl_names.each {|cl|
          eq_lefts << eq_left.gsub('_cl', "_#{cl}")
        }
      end
      eq << eq_lefts.join(' + ') + " #{eq_right};"
    }
    eq.join("\n")

  end

  def read_definition(io)
    io.each {|line|
      line.strip!
      line.sub!(/,*$/, '')                       # 行末尾のカンマは削除
      next if line.size == 0 or line =~ /^#/     # 空白行と行頭#は無視する
      keyword, op1, op2 = line.split(':')
      case keyword
      when 'class'
        set_class(op1, op2)
      when 'type'
        add_type(op1, op2)
      when 'constraint'
        add_constraint(op1)
      when 'constraint_sum'
        add_constraint_sum(op1)
      when 'weight'
        set_weight(op1)
      else
        add_member(keyword, op1, op2)
      end
    }
  end
  def eq_all
    eq = []
    eq << eq_max
    eq << eq_type_need
    eq << eq_constraint
    eq << eq_constraint_sum
    eq << eq_int01
    eq.join("\n\n")
  end
end

nt = LP_notetaker.new

File.open('nt.csv', 'r') {|f|
  nt.read_definition(f)
}
#p nt
print nt.eq_all

