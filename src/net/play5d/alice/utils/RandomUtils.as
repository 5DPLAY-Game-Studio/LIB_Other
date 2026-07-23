/*
 * Copyright (C) 2021-2026, 5DPLAY Game Studio
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

package net.play5d.alice.utils {
import flash.utils.getTimer;

/**
 * 可指定种子的伪随机数工具。
 *
 * <p>基于 xorshift 生成可复现序列；共享状态用 <code>RandomUtils.I</code>，亦可
 * <code>new</code> 独立实例。非种子场景见 <code>KyoRandom</code>。</p>
 *
 * @example
 * <listing version="3.0">
 * RandomUtils.I.setSeed(12345);
 * var n:Number = RandomUtils.I.getNext();
 * </listing>
 * @see #setSeed()
 * @see #getNext()
 * @see net.play5d.kyo.utils.KyoRandom
 */
public class RandomUtils {

    /** @private 将 uint 状态映射到 [0, 1) */
    private static const MAX_RATIO:Number = 1 / uint.MAX_VALUE;

    /** @private 单例 */
    private static var _i:RandomUtils;

    /**
     * 单例。
     * @return 共享实例。
     */
    public static function get I():RandomUtils {
        if (!_i) {
            _i = new RandomUtils();
        }
        return _i;
    }

    /** @private 初始种子（用于复现序列） */
    private var _seed:uint = 0;
    /** @private 当前 xorshift 状态 */
    private var _r:uint = 0;

    /**
     * 创建生成器。
     * @param seed 初始种子；为 <code>0</code> 时用 <code>getTimer()</code>。
     */
    public function RandomUtils(seed:uint = 0) {
        setSeed(seed);
    }

    /**
     * 设置种子并重置序列。
     * @param seed 种子；为 <code>0</code> 时取 <code>getTimer()</code>（仍为 0 则用 1）。
     * @example
     * <listing version="3.0">
     * RandomUtils.I.setSeed(42);
     * </listing>
     * @see #getSeed()
     * @see #reset()
     */
    public function setSeed(seed:uint):void {
        if (seed == 0) {
            seed = uint(getTimer()) || 1;
        }
        _r = _seed = seed;
    }

    /**
     * 最近一次写入的初始种子。
     * @return 初始种子（非当前推进状态）。
     * @example
     * <listing version="3.0">
     * var s:uint = RandomUtils.I.getSeed();
     * </listing>
     * @see #setSeed()
     */
    public function getSeed():uint {
        return _seed;
    }

    /**
     * 当前推进状态（可中途存档）。
     * @return 状态值。
     * @example
     * <listing version="3.0">
     * var st:uint = RandomUtils.I.getState();
     * </listing>
     * @see #setState()
     */
    public function getState():uint {
        return _r;
    }

    /**
     * 恢复推进状态（不改变初始种子）。
     * @param state 先前 <code>getState</code> 得到的值；为 <code>0</code> 时用 1。
     * @example
     * <listing version="3.0">
     * RandomUtils.I.setState(st);
     * </listing>
     * @see #getState()
     */
    public function setState(state:uint):void {
        _r = state || 1;
    }

    /**
     * 将序列重置为当前种子的起始状态。
     * @example
     * <listing version="3.0">
     * RandomUtils.I.reset();
     * </listing>
     * @see #setSeed()
     */
    public function reset():void {
        _r = _seed;
    }

    /**
     * 产生下一个伪随机数。
     * @return <code>[0, 1)</code> 内的数值。
     * @example
     * <listing version="3.0">
     * var n:Number = RandomUtils.I.getNext();
     * </listing>
     * @see #getNextInt()
     * @see #getNextFloat()
     */
    public function getNext():Number {
        return nextState() * MAX_RATIO;
    }

    /**
     * 产生闭区间内的下一个整数。
     * @param min 下界（含）。
     * @param max 上界（含）。
     * @return <code>[min, max]</code> 内的整数。
     * @example
     * <listing version="3.0">
     * var i:int = RandomUtils.I.getNextInt(1, 6);
     * </listing>
     * @see #getNext()
     */
    public function getNextInt(min:int, max:int):int {
        if (min > max) {
            var swap:int = min;
            min          = max;
            max          = swap;
        }
        var range:uint = uint(max - min + 1);
        return min + int(nextState() % range);
    }

    /**
     * 产生半开区间内的下一个浮点数。
     * @param min 下界（含）。
     * @param max 上界（不含）。
     * @return <code>[min, max)</code> 内的数值。
     * @example
     * <listing version="3.0">
     * var n:Number = RandomUtils.I.getNextFloat(0, 100);
     * </listing>
     * @see #getNext()
     */
    public function getNextFloat(min:Number, max:Number):Number {
        if (min > max) {
            var swap:Number = min;
            min             = max;
            max             = swap;
        }
        return min + getNext() * (max - min);
    }

    /**
     * 按概率产生布尔值。
     * @param rate 为 <code>true</code> 的概率，范围建议 <code>[0, 1]</code>。
     * @return 是否命中。
     * @default 0.5
     * @example
     * <listing version="3.0">
     * if (RandomUtils.I.getNextBoolean(0.3)) {
     * }
     * </listing>
     * @see #getNext()
     */
    public function getNextBoolean(rate:Number = 0.5):Boolean {
        return getNext() < rate;
    }

    /**
     * 产生随机符号。
     * @return <code>1</code> 或 <code>-1</code>。
     * @example
     * <listing version="3.0">
     * var s:int = RandomUtils.I.getNextSign();
     * </listing>
     * @see #getNextBoolean()
     */
    public function getNextSign():int {
        return getNextBoolean() ? 1 : -1;
    }

    /**
     * 从类数组中随机取一项。
     * @param array 含 <code>length</code> 的类数组；可空。
     * @param remove 为 <code>true</code> 时从原数组 <code>splice</code> 该项。
     * @return 元素；无效数组则为 <code>null</code>。
     * @example
     * <listing version="3.0">
     * var v:* = RandomUtils.I.getNextInArray([1, 2, 3]);
     * </listing>
     * @see #shuffle()
     */
    public function getNextInArray(array:Object, remove:Boolean = false):* {
        if (array == null || array.length < 1) {
            return null;
        }
        var index:int = getNextInt(0, int(array.length) - 1);
        var item:*    = array[index];
        if (remove) {
            array.splice(index, 1);
        }
        return item;
    }

    /**
     * 原地 Fisher–Yates 洗牌。
     * @param array 目标数组；为 <code>null</code> 则忽略。
     * @return 同一数组引用。
     * @example
     * <listing version="3.0">
     * RandomUtils.I.shuffle(list);
     * </listing>
     * @see #getNextInArray()
     */
    public function shuffle(array:Array):Array {
        if (array == null) {
            return null;
        }
        for (var i:int = array.length - 1; i > 0; i--) {
            var j:int = getNextInt(0, i);
            var t:*   = array[i];
            array[i]  = array[j];
            array[j]  = t;
        }
        return array;
    }

    /** @private 推进 xorshift 状态并返回（位移量对 32 取模，>>>35 等价 >>>3） */
    private function nextState():uint {
        _r ^= (_r << 21);
        _r ^= (_r >>> 3);
        _r ^= (_r << 4);
        return _r;
    }

}
}
