using Sandbox;
using System;

[Title( "Kuwahara Filter" )]
[Category( "Post Processing" )]
[Icon( "zoom_out_map" )]
public sealed class KuwaharaFilter : Component, Component.ExecuteInEditor
{
    /// <summary>
    /// Switches to the directional variant of the Kuwahara Filter which better preserves edges and details. (More Expensive)
    /// </summary>
    [Property]
    public bool Directional { get; set; } = false;
 
    /// <summary>
    /// Higher the radius the higher the performance cost.
    /// </summary>
    [Property, Range( 0.0f, 16.0f )]  //  ToggleGroup( "DirectionalEnabled" ),
    public float RadiusX { get; set; } = 5.0f;

    /// <summary>
    /// Higher the radius the higher the performance cost.
    /// </summary>
    [Property,Range( 0.0f, 16.0f )]  // ToggleGroup( "DirectionalEnabled" ),
    public float RadiusY { get; set; } = 3.0f;

    IDisposable renderHook;

    protected override void OnEnabled()
    {
        renderHook?.Dispose();
        var cc = Components.Get<CameraComponent>( true );
        renderHook = cc.AddHookBeforeOverlay( "KuwaharaFilter", 500, RenderEffect );
    }
	
    protected override void OnDisabled()
    {
        renderHook?.Dispose();
        renderHook = null;
    }

    RenderAttributes attributes = new RenderAttributes();

    public void RenderEffect( SceneCamera camera )
    {
        if ( !camera.EnablePostProcessing )
            return;

		// Set our Shader attributes.
		//attributes.Set( "Kuwahara.Directional", Directional );
		attributes.Set( "Kuwahara.RadiusX", RadiusX );
        attributes.Set( "Kuwahara.RadiusY", RadiusY );

		// Set our Shader Combos.
		attributes.SetCombo( "D_DIRECTIONAL", Directional );

		Graphics.GrabFrameTexture( "ColorBuffer", attributes );
        Graphics.GrabDepthTexture( "DepthBuffer", attributes );
        Graphics.Blit( Material.Load( "materials/postprocess/kuwahara_filter.vmat" ), attributes );

    }
}
