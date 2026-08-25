import Cropper from "cropperjs"

document.addEventListener('DOMContentLoaded', () => {
  const fileInput = document.getElementById('avatar-upload-input')
  if (!fileInput) return

  const modal = document.getElementById('crop-modal')
  const cropImage = document.getElementById('crop-image')
  const zoomSlider = document.getElementById('crop-zoom-slider')
  const cancelBtn = document.getElementById('crop-cancel-btn')
  const applyBtn = document.getElementById('crop-apply-btn')
  const avatarIcon = document.querySelector('.avatar-icon')
  const avatarPreview = document.getElementById('avatar-preview')

  let cropper = null

  const openModal = (dataUrl) => {
    cropImage.src = dataUrl
    modal.style.display = 'flex'

    cropper = new Cropper(cropImage, {
      aspectRatio: 1,
      viewMode: 1,
      dragMode: 'move',
      background: false,
      autoCropArea: 1,
      cropBoxMovable: false,
      cropBoxResizable: false,
      guides: false,
      center: false,
      highlight: false,
      ready() {
        zoomSlider.value = 0
      },
    })
  }

  const closeModal = () => {
    cropper?.destroy()
    cropper = null
    modal.style.display = 'none'
    fileInput.value = ''
  }

  fileInput.addEventListener('change', () => {
    const file = fileInput.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => openModal(e.target.result)
    reader.readAsDataURL(file)
  })

  zoomSlider?.addEventListener('input', (e) => {
    cropper?.zoomTo(parseFloat(e.target.value))
  })

  cancelBtn?.addEventListener('click', closeModal)

  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal()
  })

  applyBtn?.addEventListener('click', () => {
    if (!cropper) return

    cropper.getCroppedCanvas({ width: 400, height: 400 }).toBlob((blob) => {
      if (!blob) return

      avatarPreview.src = URL.createObjectURL(blob)
      avatarPreview.style.display = 'block'
      avatarIcon.style.display = 'none'

      const croppedFile = new File([blob], 'avatar.png', { type: 'image/png' })
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(croppedFile)
      fileInput.files = dataTransfer.files

      cropper.destroy()
      cropper = null
      modal.style.display = 'none'
    }, 'image/png')
  })
})
