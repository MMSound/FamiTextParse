/// @description parse a famitracker text export into an identically-named json file
function ft_text_parse(_name)
{
	var _file = file_text_open_read(_name);
	var _module = {};

	if (_file != -1)
	{
		var _mode = "";
		var _currentStruct = noone;
		var _currentStructName = "";
		var _currentStructNameFirst = "";
		var _currentIndex = -1;
		var _currentSubStruct = noone;
		var _currentSubIndex = -1;
		var _defaultGroove = [];
		while (!file_text_eof(_file))
		{
			var _line = file_text_readln(_file);
			var _str = string_lower(_line);
			var _newline = false;
			var _newlineArray = [" ", "\r\n", "\r", "\n"];
		
			if (is_struct(_currentSubStruct)) //push previous song struct if it exists so we don't lose it
			{
				_currentStruct.track[_currentIndex] = _currentSubStruct;
			}
		
			//so we can skip newlines
			if (array_contains(_newlineArray, _str))
			{
				_newline = true;
			}
		
			//now the messy part where we hardcode everything
			if (string_pos("famitracker", _str) != 0)
			{
				_mode = "";
			}
			else
			{
				if (string_char_at(_str, 1) == "#")
				{
					if (is_struct(_currentStruct))
					{
						var _struct = struct_get_names(_currentStruct);
						if (array_length(_struct) != 0 && _currentStructName != "") //push struct to module but only if it exists
						{
							variable_struct_set(_module, _currentStructName, _currentStruct);
							_currentStruct = noone;
							_currentStructName = "";
							_currentStructNameFirst = "";
							_currentSubStruct = noone;
						}
					}
					_mode = "newstruct";
					var _lineArr = string_split_ext(_str, _newlineArray, true);
					var _newName = "";
					for (var i = 1; i < array_length(_lineArr); i++) //assemble a new name
					{
						var _next = _lineArr[i];
						if (i > 1)
						{
							_next = string(string_upper(string_char_at(_next, 1)) + string_copy(_next, 2, string_length(_next)));
						}
						else
						{
							_currentStructNameFirst = _next;
						}
						_newName = string_concat(_newName, _next);
					}
					_currentStructName = _newName;
				}
				else
				{
					//do nothing ig
				}
			}
		
			if (_mode == "")
			{
				continue;
			}
			else
			{
				switch (_mode)
				{
					case "newstruct": //set up the struct we're adding to
						_mode = "addtostruct";
						_currentStruct = {};
						_currentIndex = -1;
						_currentSubIndex = -1;
						break;
					case "addtostruct": //add to our current struct
						if (!_newline)
						{
							switch (_currentStructNameFirst) //by using the first name we can easily determine how to process data
							{
								case "song":
									array_push(_newlineArray, "\"");
									var _lineArr = string_split_ext(_str, _newlineArray, true);
									switch (_lineArr[0]) //basically hardcoding how we interpret the line
									{
										case "title":
										case "author":
										case "copyright":
										case "comment":
											var _lineArrCased = string_split_ext(_line, ["\"", "\r\n", "\r", "\n"], true); //keep spaces
											if (array_length(_lineArrCased) > 1)
											{
												variable_struct_set(_currentStruct, _lineArr[0], _lineArrCased[1]);
											}
											else
											{
												variable_struct_set(_currentStruct, _lineArr[0], "");
											}
											break;
									}
									break;
								case "global":
									var _lineArr = string_split_ext(_str, _newlineArray, true);
									variable_struct_set(_currentStruct, _lineArr[0], _lineArr[1]);
									break;
								case "macros":
									var _lineArr = string_split_ext(_str, _newlineArray, true);
									var _arrName = "";
									switch (_lineArr[1]) //name of array to set
									{
										case 0: _arrName = "volume"; break;
										case 1: _arrName = "arpeggio"; break;
										case 2: _arrName = "pitch"; break;
										case 3: _arrName = "hiPitch"; break;
										case 4: _arrName = "duty"; break;
									}
									if (!variable_struct_exists(_currentStruct, _arrName)) //add this variable if it doesn't yet exist
									{
										variable_struct_set(_currentStruct, _arrName, []);
									}
									var _macro = "";
									for (var i = 7; i < array_length(_lineArr); i++) //set the macro by turning it into a string
									{
										if ((i - 7) == real(_lineArr[3])) //loop
										{
											_macro += "| ";
										}
										if ((i - 7) == real(_lineArr[4])) //release
										{
											_macro += "/ ";
										}
										_macro += _lineArr[i];
										_macro += " ";
									}
									variable_struct_get(_currentStruct, _arrName)[real(_lineArr[2])] = [_macro, real(_lineArr[5])]; //i can't believe this works
									break;
								case "dpcm":
									var _lineArr = string_split_ext(_str, _newlineArray, true);
									if (_lineArr[0] == "dpcmdef") //start a new sample
									{
										var _lineArrCased = string_split_ext(_line, ["\"", "\r\n", "\r", "\n"], true); //keep spaces to get the name
										if (!variable_struct_exists(_currentStruct, "sample")) //add this variable if it doesn't yet exist
										{
											variable_struct_set(_currentStruct, "sample", []);
										}
										_currentIndex = real(_lineArr[1]);
										variable_struct_get(_currentStruct, "sample")[_currentIndex] =
										{
											size: real(_lineArr[2]),
											name: _lineArrCased[1],
											data: []
										};
									}
									else if (_lineArr[0] == "dpcm")
									{
										var _data = [];
										for (var i = 2; i < array_length(_lineArr); i++) //add to sample
										{
											_data[i - 2] = _lineArr[i];
										}
										if (_currentIndex != -1)
										{
											_currentStruct.sample[_currentIndex].data = array_concat(_currentStruct.sample[_currentIndex].data, _data);
										}
									}
									break;
								case "detune": //come back to this later
								
									break;
								case "grooves":
									var _lineArr = string_split_ext(_str, _newlineArray, true);
									if (!variable_struct_exists(_currentStruct, "groove")) //add this variable if it doesn't yet exist
									{
										variable_struct_set(_currentStruct, "groove", []);
									}
									var _data = [];
									for (var i = 4; i < array_length(_lineArr); i++) //add to sample
									{
										_data[i - 4] = real(_lineArr[i]);
									}
									variable_struct_get(_currentStruct, "groove")[real(_lineArr[1])] = _data;
									break;
								case "instruments":
									var _lineArr = string_split_ext(_str, _newlineArray, true);
									if (_lineArr[0] != "keydpcm") //add instrument data
									{
										var _lineArrCased = string_split_ext(_line, ["\"", "\r\n", "\r", "\n"], true); //keep spaces to get the name
										if (!variable_struct_exists(_currentStruct, "instrument")) //add this variable if it doesn't yet exist
										{
											variable_struct_set(_currentStruct, "instrument", []);
										}
										_currentIndex = real(_lineArr[1]);
										_currentStruct.instrument[_currentIndex] =
										{
											chip: string_copy(_lineArr[0], 5, string_length(_lineArr[0])),
											name: _lineArrCased[1],
											macros:
											{
												volume: _lineArr[2],
												arpeggio: _lineArr[3],
												pitch: _lineArr[4],
												hiPitch: _lineArr[5],
												duty: _lineArr[6]
											},
											dpcm: noone
										};
									}
									else //add dpcm
									{
										if (_currentStruct.instrument[_currentIndex].dpcm == noone)
										{
											_currentStruct.instrument[_currentIndex].dpcm = array_create(8, noone);
											for (var i = 0; i < 8; i++)
											{
												_currentStruct.instrument[_currentIndex].dpcm[i] = array_create(12, noone);
											}
										}
										_currentStruct.instrument[_currentIndex].dpcm[real(_lineArr[2])][real(_lineArr[3])] =
										{
											sample: real(_lineArr[4]),
											pitch: real(_lineArr[5]),
											loop: (real(_lineArr[6]) != 0 ? real(_lineArr[7]) : -1),
											delta: real(_lineArr[8])
										};
									}
									break;
								case "tracks":
									if (_currentStructName == "tracksUsingDefaultGroove") //i don't care about saving this info as a separate struct but we do need it
									{
										var _lineArr = string_split_ext(_str, _newlineArray, true);
										if (_lineArr[0] == "usegroove")
										{
											for (var i = 2; i < array_length(_lineArr); i++)
											{
												array_push(_defaultGroove, real(_lineArr[i]));
											}
										}
									}
									else //The Big One
									{
										if (_currentIndex == -1)
										{
											_currentIndex = 0;
											_currentStruct.track = [];
										}
										var _lineArr = string_split_ext(_str, _newlineArray, true);
										switch (_lineArr[0])
										{
											case "track":
												if (is_struct(_currentSubStruct)) //push previous song struct, increment counter
												{
													_currentStruct.track[_currentIndex++] = _currentSubStruct;
													_currentSubStruct = {};
												}
												else
												{
													_currentSubStruct = {};
												}
												var _lineArrCased = string_split_ext(_line, ["\"", "\r\n", "\r", "\n"], true); //keep spaces to get the name
												if (array_length(_lineArrCased) > 0)
												{
													_currentSubStruct.name = _lineArrCased[1];
													_currentSubStruct.defaultGroove = array_contains(_defaultGroove, (_currentIndex + 1));
													_currentSubStruct.speed = _lineArr[2];
													_currentSubStruct.tempo = _lineArr[3];
													_currentSubStruct.rows = _lineArr[1];
													_currentSubStruct.channel = [];
												}
												break;
											case "order": //frames
												if (!variable_struct_exists(_currentSubStruct, "frame"))
												{
													variable_struct_set(_currentSubStruct, "frame", []);
												}
												var _frame = [];
												for (var i = 3; i < array_length(_lineArr); i++)
												{
													_frame[i - 3] = real(hextodec(_lineArr[i]));
												}
												variable_struct_get(_currentSubStruct, "frame")[real(hextodec(_lineArr[1]))] = _frame;
												break;
											case "pattern":
												_currentSubIndex = real(hextodec(_lineArr[1]));
												break;
											case "row": //The Really Big One
												var _row = string_split_ext(string_lower(_line), ["\"", "\r\n", "\r", "\n", ":"]); //keep spaces for further parsing
												var _num = 0;
												for (var i = 0; i < array_length(_row); i++)
												{
													var _arr = string_split(_row[i], " ", true);
													if (array_length(_arr) > 0)
													{
														if (_arr[0] == "row") //get row number
														{
															_num = hextodec(_arr[1]);
														}
														else if (i > 0)
														{
															var _chan = (i - 1);
															if (_chan >= array_length(_currentSubStruct.channel))
															{
																_currentSubStruct.channel[_chan] = [];
															}
															if (_currentSubIndex >= array_length(_currentSubStruct.channel[_chan]))
															{
																_currentSubStruct.channel[_chan][_currentSubIndex] = [];
															}
														
															//finally parse the row - i wonder if it's worth making this a struct
															var _data = [];
															var _effects = -1;
															for (var j = 0; j < array_length(_arr); j++)
															{
																var _str = _arr[j];
																switch (j)
																{
																	case 0: //note
																		switch (_str)
																		{
																			case "...": //no note
																				_data[0] = -1;
																				break;
																			case "---":
																				_data[0] = "cut";
																				break;
																			case "===":
																				_data[0] = "release";
																				break;
																			default:
																				_data[0] = note_parse(_str);
																				break;
																		}
																		break;
																	case 1: //instrument
																		if (_str == "..")
																		{
																			_data[1] = -1;
																		}
																		else if (_str == "&&")
																		{
																			_data[1] = "&&";
																		}
																		else
																		{
																			_data[1] = real(hextodec(_str));
																		}
																		break;
																	case 2: //volume
																		if (_str == ".")
																		{
																			_data[2] = -1;
																		}
																		else
																		{
																			_data[2] = real(hextodec(_str));
																		}
																		break;
																	default: //effects
																		var _effect = -1;
																		if (_str != "...")
																		{
																			_effect = [string_char_at(_str, 1), real(hextodec(string_copy(_str, 2, string_length(_str))))];
																			if (!is_array(_effects))
																			{
																				_effects = [];
																			}
																		}
																		if (is_array(_effects))
																		{
																			_effects[j - 3] = _effect;
																		}
																		break;
																}
															}
															_data[3] = _effects;
														
															var _blank = true;
															for (var j = 0; j < array_length(_data); j++)
															{
																if (_data[j] != -1)
																{
																	_blank = false;
																	break;
																}
															}
															if (!_blank)
															{
																_currentSubStruct.channel[_chan][_currentSubIndex][_num] = _data;
															}
														}
													}
												}
												break;
										}
										break;
									}
									break;
							}
						}
						break;
					default:
					
						break;
				}
			}
		}
	}

	file_text_close(_file);
	
	var _newName = string_split(_name, ".");
	_file = file_text_open_write(string(_newName[0] + ".json"));
	file_text_write_string(_file, json_stringify(_module, true));
	file_text_close(_file);
}

/// @description convert a hexadecimal string to a decimal number - GMLscripts.com/license; modified by MiniMacro Sound
function hextodec(_hex)
{
	var _new = 0;
	_hex = string_lower(_hex);
	for (var i = 1; i <= string_length(_hex); i++)
	{
		_new = (_new << 4 | (string_pos(string_char_at(_hex, i), "0123456789abcdef") - 1));
	}
	return _new;
}

/// @description parse a note
function note_parse(_str)
{
	if (string_pos("^", _str) != 0) //echo buffer
	{
		return [string_char_at(_str, 3), "echo"];
	}
	
	if (string_char_at(_str, 3) == "#") //noise
	{
		return [real(hextodec(string_char_at(_str, 1))), "noise"];
	}

	var _noteStr = string_lower(string_char_at(_str, 1));
	var _sharp = (string_char_at(_str, 2) == "#");
	var _oct = real(string_char_at(_str, 3));
	var _note = 0;
	switch (_noteStr)
	{
		case "c": _note = 0; _note += _sharp; break;
		case "d": _note = 2; _note += _sharp; break;
		case "e": _note = 4; break;
		case "f": _note = 5; _note += _sharp; break;
		case "g": _note = 7; _note += _sharp; break;
		case "a": _note = 9; _note += _sharp;  break;
		case "b": _note = 11; break;
	}
	return [_note, _oct];
}