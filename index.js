$(document).ready(function() {
    // Array of Moroccan sweets (for the Sweets Section)
    const sweets = [
        { name: "Chebakia", description: "Honey-coated sesame cookies.", img: "img/gettyimages-658202048-612x612.jpg" },
        { name: "Kaab el Ghzal", description: "Almond-filled crescent pastries.", img: "img/gettyimages-2156187804-612x612.jpg" },
        { name: "Briouat", description: "Sweet pastry with almonds and honey.", img: "img/gettyimages-689087120-612x612.jpg" }
    ];

    // Dynamically add sweets to the page
    sweets.forEach(sweet => {
        const sweetHtml = `
            <div class="col-md-4 mb-4">
                <div class="card sweet-card shadow">
                    <img src="${sweet.img}" class="card-img-top" alt="${sweet.name}">
                    <div class="card-body">
                        <h5 class="card-title">${sweet.name}</h5>
                        <p class="card-text">${sweet.description}</p>
                    </div>
                </div>
            </div>
        `;
        $("#sweets-list").append(sweetHtml);
    });

    // Smooth scrolling for navigation links
    $("a[href^='#']").on("click", function(event) {
        if (this.hash !== "") {
            event.preventDefault();
            const hash = this.hash;
            $("html, body").animate({
                scrollTop: $(hash).offset().top
            }, 800);
        }
    });
});