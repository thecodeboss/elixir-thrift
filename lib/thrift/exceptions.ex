defmodule Thrift.TApplicationException do
  defexception message: nil, type: nil


  def exception_type(1), do: :unknown_method
  def exception_type(2), do: :invalid_message_type
  def exception_type(3), do: :wrong_method_name
  def exception_type(4), do: :bad_sequence_id
  def exception_type(5), do: :missing_result
  def exception_type(6), do: :internal_error
  def exception_type(7), do: :protocol_error
  def exception_type(8), do: :invalid_transform
  def exception_type(9), do: :invalid_protocol
  def exception_type(10), do: :unsupported_client_type
  def exception_type(_), do: :unknown
end

defmodule Thrift.Union.TooManyFieldsSetException do
  @moduledoc """
  This exception occurs when a Union is serialized and more than one
  field is set.
  """
  defexception message: nil, set_fields: nil
end

defmodule Thrift.FileParseException do
  @moduledoc """
  This exception occurs when a thrift file fails to parse
  """

  defexception message: nil

  @doc false  # Exception callback, should not be called by end user
  @spec exception({Thrift.Parser.FileRef.t, term}) :: Exception.t
  def exception({file_ref, error}) do
    msg = "Error parsing thrift file #{file_ref.path} #{format_error(error)}"
    %Thrift.FileParseException{message: msg}
  end

  # display the line number if we get it
  defp format_error({line_no, :thrift_parser, errors}) do
    "on line #{line_no}: #{inspect errors}"
  end
  defp format_error({{line_no, :thrift_lexer, errors}, _}) do
    "on line #{line_no}: #{inspect errors}"
  end
  defp format_error(error) do
    ":#{inspect error}"
  end
end
