using Sandbox;
using Sandbox.Rendering;

[Title( "Kuwahara Filter" )]
[Category( "Post Processing" )]
[Icon( "zoom_out_map" )]
public sealed class KuwaharaFilter : BasePostProcess<KuwaharaFilter>
{
	/// <summary>
	/// Switches to the directional variant of the Kuwahara Filter which better preserves edges and details. (More Expensive)
	/// </summary>
	[Property]
	public bool Directional { get; set; } = false;
	
	/// <summary>
	/// Higher the radius the higher the performance cost.
	/// </summary>
	[Property, Range( 0.0f, 16.0f )]	// ToggleGroup( "DirectionalEnabled" ),
	public float RadiusX { get; set; } = 5.0f;
	
	/// <summary>
	/// Higher the radius the higher the performance cost.
	/// </summary>
	[Property, Range( 0.0f, 16.0f )]	// ToggleGroup( "DirectionalEnabled" ),
	public float RadiusY { get; set; } = 3.0f;

	public override void Render()
	{
		Attributes.Set( "Kuwahara.RadiusX", RadiusX );
		Attributes.Set( "Kuwahara.RadiusY", RadiusY );

		Attributes.SetCombo( "D_DIRECTIONAL", Directional );

		var shader = Material.FromShader( "shaders/postprocess/postprocess_kuwahara_filter.shader" );
		var blit = BlitMode.WithBackbuffer( shader, Stage.AfterPostProcess, 200, false );
		Blit( blit, "KuwaharaFilter" );
	}
}
