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
import flash.display.DisplayObject;
import flash.events.Event;
import flash.utils.Dictionary;
import flash.utils.describeType;
import flash.utils.getQualifiedClassName;

/**
 * 类反射与路径访问工具。
 *
 * <p>提供公开属性枚举、事件处理方法探测、嵌套路径访问等；
 * <code>describeType</code> 结果按类缓存。</p>
 *
 * @see #getClassProperty()
 * @see #continuousAccess()
 */
public class ClassUtils {

    /** @private <code>flash.events.Event</code> 限定名 */
    private static const EVENT_QNAME:String = 'flash.events.Event';

    /** @private Class → 公开变量名列表 */
    private static var _propCache:Dictionary        = new Dictionary(true);
    /** @private 限定类名 → 本类声明的 Event 处理方法名 */
    private static var _eventMethodCache:Dictionary = new Dictionary();
    /** @private 路径 key → 预编译访问器 */
    private static var _pathCache:Dictionary        = new Dictionary();

    /**
     * 获得类的公开实例变量名（不含访问器）。
     * @param cls 类；为 <code>null</code> 则返回 <code>null</code>。
     * @return 属性名数组；无则空数组。
     * @example
     * <listing version="3.0">
     * var keys:Array = ClassUtils.getClassProperty(HitVO);
     * </listing>
     */
    public static function getClassProperty(cls:Class):Array {
        if (!cls) {
            return null;
        }

        var cached:Array = _propCache[cls] as Array;
        if (cached) {
            return cached;
        }

        var keys:Array      = [];
        var variables:XMLList = describeFactoryVariables(cls);
        if (variables) {
            for each (var varXml:XML in variables) {
                keys.push(String(varXml.@name));
            }
        }

        _propCache[cls] = keys;
        return keys;
    }

    /**
     * 获得值的限定类名。
     * @param value 任意值。
     * @return 限定名；<code>value</code> 为 <code>null</code> 则为 <code>null</code>。
     * @example
     * <listing version="3.0">
     * ClassUtils.getClassName(sprite); // 'flash.display::Sprite'
     * </listing>
     */
    public static function getClassName(value:*):String {
        if (value == null) {
            return null;
        }
        return getQualifiedClassName(value);
    }

    /**
     * 获得实例上由本类声明、且仅接受一个 <code>Event</code> 参数的方法名。
     *
     * <p>不含继承方法；参数类型须为 <code>flash.events.Event</code>（不含子类签名）。</p>
     *
     * @param value 实例；为 <code>null</code> 则返回 <code>null</code>。
     * @return 方法名数组；无则空数组。
     * @example
     * <listing version="3.0">
     * var names:Array = ClassUtils.getClassEventMethod(view);
     * </listing>
     * @see #removeAllEventListener()
     */
    public static function getClassEventMethod(value:*):Array {
        if (value == null) {
            return null;
        }

        var qname:String = getQualifiedClassName(value);
        var cached:Array = _eventMethodCache[qname] as Array;
        if (cached) {
            return cached;
        }

        var eventFuncs:Array = [];
        var methods:XMLList  = describeInstanceMethods(value);
        if (methods) {
            for each (var methodXml:XML in methods) {
                if (String(methodXml.@declaredBy) != qname) {
                    continue;
                }

                var parameters:XMLList = methodXml.parameter;
                if (parameters.length() != 1) {
                    continue;
                }
                if (String(parameters[0].@type) != EVENT_QNAME) {
                    continue;
                }

                eventFuncs.push(String(methodXml.@name));
            }
        }

        _eventMethodCache[qname] = eventFuncs;
        return eventFuncs;
    }

    /**
     * 移除显示对象上、由本类 Event 处理方法注册的全部 <code>ENTER_FRAME</code> 监听。
     * @param d 显示对象。
     * @param back 每成功移除一个时回调，参数为方法名 <code>String</code>。
     * @example
     * <listing version="3.0">
     * ClassUtils.removeAllEventListener(mc);
     * </listing>
     * @see #getClassEventMethod()
     */
    public static function removeAllEventListener(d:DisplayObject, back:Function = null):void {
        if (d == null || !d.hasEventListener(Event.ENTER_FRAME)) {
            return;
        }

        var eventMethods:Array = getClassEventMethod(d);
        if (!eventMethods || eventMethods.length == 0) {
            return;
        }

        for each (var eventName:String in eventMethods) {
            if (!d.hasEventListener(Event.ENTER_FRAME)) {
                break;
            }

            var eventFunc:Function = d[eventName] as Function;
            if (eventFunc == null) {
                continue;
            }

            d.removeEventListener(Event.ENTER_FRAME, eventFunc);
            if (back != null) {
                back(eventName);
            }
        }
    }

    /**
     * 按路径连续访问嵌套属性或无参方法。
     *
     * <p>方法节点以 <code>()</code> 结尾。相同路径会编译并缓存访问器。</p>
     *
     * @param begin 起始对象。
     * @param list 路径段；为 <code>null</code> 或空则返回 <code>begin</code>。
     * @return 末端值；中途为 <code>null</code>/<code>undefined</code> 则返回 <code>null</code>。
     * @example
     * <listing version="3.0">
     * var text:* = ClassUtils.continuousAccess(lang, ['menu', 'start']);
     * var child:* = ClassUtils.continuousAccess(root, ['getChildAt()', 'name']);
     * </listing>
     */
    public static function continuousAccess(begin:*, list:Array = null):* {
        if (begin == null) {
            return null;
        }
        if (list == null || list.length == 0) {
            return begin;
        }

        var cacheKey:String   = list.join(',');
        var accessor:Function = _pathCache[cacheKey] as Function;
        if (accessor == null) {
            accessor             = compileAccessor(list);
            _pathCache[cacheKey] = accessor;
        }
        return accessor(begin);
    }

    /** @private 读取 Class 的 factory.variable */
    private static function describeFactoryVariables(cls:Class):XMLList {
        try {
            return describeType(cls).factory.variable;
        }
        catch (e:Error) {
        }
        return null;
    }

    /** @private 读取实例的 method 列表 */
    private static function describeInstanceMethods(value:*):XMLList {
        try {
            return describeType(value).method;
        }
        catch (e:Error) {
        }
        return null;
    }

    /** @private 将路径编译为访问闭包链 */
    private static function compileAccessor(list:Array):Function {
        var accessors:Array = [];
        var len:int         = list.length;

        for (var i:int = 0; i < len; i++) {
            var node:String = String(list[i]);
            if (isMethodNode(node)) {
                accessors.push(createMethodAccessor(node.substring(0, node.length - 2)));
            }
            else {
                accessors.push(createPropertyAccessor(node));
            }
        }

        return function (root:*):* {
            var current:* = root;
            for each (var func:Function in accessors) {
                if (current == null) {
                    return null;
                }
                current = func(current);
                if (current == null) {
                    return null;
                }
            }
            return current;
        };
    }

    /** @private 路径段是否为无参方法调用（以 () 结尾） */
    private static function isMethodNode(node:String):Boolean {
        return node.length > 2 && node.substr(-2) == '()';
    }

    /** @private */
    private static function createPropertyAccessor(name:String):Function {
        return function (obj:*):* {
            return obj[name];
        };
    }

    /** @private */
    private static function createMethodAccessor(name:String):Function {
        return function (obj:*):* {
            var m:* = obj[name];
            if (m is Function) {
                return (m as Function)();
            }
            return null;
        };
    }

}
}
