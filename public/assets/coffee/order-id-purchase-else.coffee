$ ->
  $('#btn-toggle-parcel').click (e) ->
    $('#form-parcel').toggleClass('hide')

  $('#btn-comment').click (e) ->
    $('#form-comment').toggleClass('hide')

  $('.btn-cancel').click (e) ->
    $(@).closest('form').addClass('hide')

  checked = {}
  $('.checkbox-code').each ->
    id  = $(@).prop('id')
    val = $(@).prop('checked')
    checked[id] = val
    true

  $('#form-clothes-code').submit (e) ->
    e.preventDefault()

    $input = $('#input-code')
    code = $input.val()
    $input.val('')
    return unless code

    code = code.toUpperCase()
    $("#code-#{code}").trigger('click')

  $('.checkbox-code').change (e) ->
    id  = $(@).prop('id')
    val = $(@).prop('checked')
    checked[id] = val
    values = _.values checked

    if _.every values
      # 전체반납
      $('#btn-return-all').removeClass('disabled')
      $('#btn-return-partial').addClass('disabled')
      $('#input-status-id').val(9)
    else if _.every(values, (b) -> not b)
      $('#btn-return-all').addClass('disabled')
      $('#btn-return-partial').addClass('disabled')
    else
      # 부분반납
      $('#btn-return-all').addClass('disabled')
      $('#btn-return-partial').removeClass('disabled')
      $('#input-status-id').val(10)

  $('#form-update-order').on 'click', '#btn-return-all:not(.disabled)', (e) ->
    $this = $(@)
    $this.addClass('disabled')
    $form = $('#form-update-order')
    url = $form.prop('action')
    $.ajax url,
      type: 'PUT'
      data: $form.serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title:textStatus, message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $('.btn-parcel-status').click (e) ->
    e.preventDefault()
    $this = $(@)
    return if $this.hasClass('disabled')
    return unless confirm "배송상태를 변경하시겠습니까?"

    $.ajax $this.prop('href'),
      type: 'PUT'
      dataType: 'json'
      data: { status_id: $this.data('status') }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title:textStatus, message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
