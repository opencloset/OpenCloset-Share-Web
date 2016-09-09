$ ->
  $('#btn-toggle-parcel').click (e) ->
    $('#form-parcel').removeClass('hide')

  $('#btn-comment').click (e) ->
    $('#form-comment').removeClass('hide')

  $('#btn-sms').click (e) ->
    $('#form-sms').removeClass('hide')

  $('.btn-cancel').click (e) ->
    $(@).closest('form').addClass('hide')

  $('#form-sms').submit (e) ->
    e.preventDefault()
    $this = $(@)
    $.ajax $this.attr('action'),
      type: $this.attr('method')
      data: $this.serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: 'Sent a SMS', message: "#{data.text}" })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title: textStatus, message: "#{jqXHR.responseJSON.error}" })
      complete: (jqXHR, textStatus) ->
        $this.find('textarea').val('')
        $this.find('.btn-cancel').trigger('click')
