// Copyright 2016-2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
// Copied from Volta and slightly modified.
/*!
 * Helper struct to sink things.
 */
module deqp.sinks;


struct StringsSink = mixin SinkStruct!string;

struct SinkStruct!(T)
{
public:
	//! The one true sink definition.
	alias Sink = void delegate(SinkArg);

	//! The argument to the one true sink.
	alias SinkArg = scope T[];

	enum size_t MinSize = 16;
	enum size_t MaxSize = 2048;

	@property size_t length()
	{
		return mLength;
	}


private:
	mStore: T[32];
	mArr: T[];
	mLength: size_t;


public:
	fn sink(type: T)
	{
		auto newSize = mLength + 1;
		if (mArr.length == 0) {
			mArr = mStore[0 .. $];
		}

		if (newSize <= mArr.length) {
			mArr[mLength++] = type;
			return;
		}

		auto allocSize = mArr.length;
		while (allocSize < newSize) {
			if (allocSize >= MaxSize) {
				allocSize += MaxSize;
			} else {
				allocSize = allocSize * 2;
			}
		}

		auto n = new T[](allocSize);
		n[0 .. mLength] = mArr[0 .. mLength];
		n[mLength++] = type;
		mArr = n;
	}

	fn append(arr: scope T[])
	{
		foreach (e; arr) {
			sink(e);
		}
	}

	fn append(s: SinkStruct)
	{
		fn func(sa: SinkArg) {
			foreach (e; sa) {
				sink(e);
			}
		}

		s.toSink(func);
	}

	fn popLast() T
	{
		if (mLength > 0) {
			return mArr[--mLength];
		}
		return T.default;
	}

	fn getLast() T
	{
		return mArr[mLength - 1];
	}

	fn get(i: size_t) T
	{
		return mArr[i];
	}

	fn set(i: size_t, n: T )
	{
		mArr[i] = n;
	}

	fn setLast(i: T)
	{
		mArr[mLength - 1] = i;
	}

	/*!
	 * Safely get the backing storage from the sink without copying.
	 */
	fn toSink(sink: Sink)
	{
		return sink(mArr[0 .. mLength]);
	}

	/*!
	 * Use this as sparingly as possible. Use toSink where possible.
	 */
	fn toArray() T[]
	{
		auto _out = new T[](mLength);
		_out[] = mArr[0 .. mLength];
		return _out;
	}

	/*!
	 * Unsafely get a reference to the array.
	 */
	fn borrowUnsafe() T[]
	{
		return mArr[0 .. mLength];
	}

	fn reset()
	{
		mLength = 0;
	}
}
